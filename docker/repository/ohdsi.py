from flask import Flask, render_template, request, send_from_directory
from urllib.request import urlopen
from urllib.request import Request
from urllib.parse import urlencode
from os import getenv
from json import loads, dumps
import simplejson
import logging
from datetime import datetime
import re
from collections import OrderedDict
import os
import json

# create app
app = Flask(__name__)
log = logging.getLogger('werkzeug')
log.disabled = True

# get ENV variables
X_API_KEY_FILE = getenv('GAIA_X_API_KEY_FILE')
GAIA_CATALOG_FLAVOR = getenv('GAIA_CATALOG_FLAVOR')
with open(X_API_KEY_FILE) as f:
    X_API_KEY = f.read().strip()

# define API parameters for different containers
apis = {
    "git": {
        "url": f"http://gaia-git:{getenv('GAIA_GIT_API_PORT')}",
        "shell": "sh"
    },
    "gdsc": {
        "url": f"http://gaia-gdsc:{getenv('GAIA_GDSC_API_PORT')}",
        "shell": "sh"
    },
    "osgeo": {
        "url": f"http://gaia-osgeo:{getenv('GAIA_OSGEO_API_PORT')}",
        "shell": "bash"
    },
    "postgis": {
        "url": f"http://gaia-postgis:{getenv('GAIA_POSTGIS_API_PORT')}",
        "shell": "bash"
    },
    "postgrest" : {
        "url": f"http://gaia-postgrest:{getenv('GAIA_POSTGREST_API_PORT')}/rpc/",
        "shell": "bash"   
    }
}

# define headers for different API flavors
headers = {
    "gdsc-api": {
        "x-api-key": X_API_KEY,
        "Content-Type": "application/octet-stream"
    },
    "gdsc-pg": {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "application/json"
    },
    "gaia-pg": {}
}

# set CONSTANTS
BASE_PATH='http://gaia-solr:8983/solr/dcat/select?wt=json&'
SNIP_LENGTH = 180
QUERY_FIELDS = ['gdsc_collections','dct_title','dcat_keyword','dct_description','gdsc_attributes']


##
 # helper functions for communication and formatting
 ##


def call_etl_api(api,func,params):
    """
    call api on ETL containers
    """

    # build payload according to api type
    if GAIA_CATALOG_FLAVOR == "gdsc-api":
        if func == "gdsc_exec": func = params['script']
        if "params" in params: parameters = f"'{dumps(params['params'])}'"
        else: parameters = ' '.join([params[param] for param in params])
        payload = f"\n{apis[api]['shell']} {func}.sh {parameters}\n\n".encode('utf-8')
    elif GAIA_CATALOG_FLAVOR == "gdsc-pg":
        api = "postgrest"
        payload = dumps(params).encode('utf-8')
    elif GAIA_CATALOG_FLAVOR == "gaia-pg":
        # not implemented
        payload = "check if gaia table is loaded"

    # build the request
    req = Request(apis[api]['url'] if GAIA_CATALOG_FLAVOR == "gdsc-api" else f"{apis[api]['url']}{func}",data=payload,method='POST')
    for header in headers[GAIA_CATALOG_FLAVOR]:
        req.add_header(header,headers[GAIA_CATALOG_FLAVOR][header])

    # make the request and read the response
    resp = urlopen(req).read()
    output = loads(resp.decode('utf-8').strip(),strict=False)
    if output in ['null','None'] or output == None: output = []

    return output['res'] if GAIA_CATALOG_FLAVOR == "gdsc-api" else output


def get_layer_meta(layer_id):
    """
    get SOLR data for one layer
    """

    query_parameters = {"q": "gdsc_tablename:" + layer_id}
    query_string  = urlencode(query_parameters)
    connection = urlopen("{}{}".format(BASE_PATH, query_string))
    response = simplejson.load(connection)
    document = response['response']['docs'][0]

    return document
    

def query_solr(path,parameters):
    """
    query solr api
    """
    numresults = 1
    results = []
    # send query to SOLR and gather paged results
    # parameters['q'] = parameters['q'].replace(' ','+')
    query_string  = urlencode(parameters).replace('-','+')
    while numresults > len(results):
        connection = urlopen("{}{}".format(path, query_string))
        response = simplejson.load(connection)
        numresults = response['response']['numFound']
        results = response['response']['docs']
        parameters["rows"] = numresults
        query_string  = urlencode(parameters).replace('-','+')
    if results == None: results = []
    return results, numresults


def highlight_query(document,query):
    """
    highlight found instances of query in document metadata
    """

    def add_tags(string_value,query):
        return re.sub(
            r'(' + term  + ')',
            '<span class="highlight-term">\g<1></span>',
            string_value,
            flags=re.IGNORECASE)

    document['found_in'] = {}
    for field in QUERY_FIELDS:
        if field in document:
            attrs = []
            for i, attr in enumerate(document[field]):
                terms = query.split(' ')
                found = True
                for term in terms:
                    if term.upper() not in attr.upper(): found = False
                if found:
                    document['found_in'][field] = []
                    row = attr.split(';')
                    if len(row) > 1:
                        row[1] = add_tags(row[1],term) # attribute description
                        attrs.append([row[0],row[1]])
                        document[field][i] = ";".join(row)
                    else:
                        for term in terms:
                            document[field][i] = add_tags(document[field][i],term)
            if len(attrs) > 0: document['found_in'][field] = attrs

    return document


##
 # route functions for app 
 ##


@app.route('/', methods=["GET","POST"])
def index():
    """
    run SOLR query and render results for main page
    """

    collection = 'all'
    query, active = None, None
    query_parameters = {"q": "gdsc_collections:*"}
    q, qf = "", "gdsc_collections "
    numresults = 1
    results = []

    # get form parameters and build SOLR query parameters
    if request.method == "POST":

        # get the form parameters
        if 'ImmutableMultiDict' in str(type(request.form)): args = request.form.to_dict()
        else: args = request.form
        if 'searchTerm' in args:
            query = re.sub(r'[\+\-\&\|\!\(\)\{\}\[\]\^\"\~\*\?\:\\]','',args["searchTerm"])
        if query == "None" or query == "": query = None
        collection = args["collection"]
        if 'active' in args:
            active = args["active"]
            if active == 'None': active = None

        # build the query parameters for SOLR
        q = collection
        if collection == 'all' or collection == '*':
            collection = '*'
            q = ""
        query_parameters = {"q": "gdsc_collections:" + collection}
        if query is not None:
            qf += ' '.join(QUERY_FIELDS)
            if len(q) > 0: q += " "
            q += query
        if active is not None:
            if qf != "gdsc_collections ": qf += " "
            qf += "gdsc_up"
            if len(q) > 0: q += " "
            q += "true"
        if qf != "gdsc_collections ":
            query_parameters = {
              "q.op": "AND",
              "defType": "dismax",
              "qf": qf,
              "q": q
            }

    # send query to SOLR and gather paged results
    results, numresults = query_solr(BASE_PATH,query_parameters)

    # check results for correct display
    for entry in results:

        # highlight search term in results
        if query != None and query != 'None' and query != '':
            entry = highlight_query(entry,query)

        # snip abstracts
        if entry['dct_description']:
            entry['display_description'] = entry['dct_description'][0]
            if len(entry['display_description']) > SNIP_LENGTH:
                entry['display_description'] = entry['dct_description'][0][0:SNIP_LENGTH] + '...'

    # check for loaded tables
    loaded_tables = call_etl_api("postgis","gdsc_get_schema_tables",{"schema_name": "public"})
    if GAIA_CATALOG_FLAVOR == "gdsc-api": loaded_tables = loaded_tables.split()[2:-2]

    # render the page
    if collection == "*": collection = 'all'
    return render_template(
        'index.html',
        collection=collection,
        query=query,
        active=active,
        numresults=numresults,
        results=results,
        loaded_tables=loaded_tables,
        collections=COLLECTIONS
    )


@app.route('/detail/<name_id>', methods=["GET","POST"])
def detail(name_id):
    """
    query SOLR for one document and render all metadata in detail
    """

    args = request.args.to_dict()

    # query solr
    document = get_layer_meta(name_id)

    # structure results for display
    if 'gdsc_attributes' in document:
        document['gdsc_columns'] = [attr.split(';')[0] for attr in document['gdsc_attributes']]
    if args['query'] != None and args['query'] != 'None' and args['query'] != '':
        document = highlight_query(document,args['query'])
    if 'gdsc_attributes' in document:
        document['gdsc_attributes'] = [attr.split(';') for attr in document['gdsc_attributes']]
    if 'gdsc_derivatives' in document:
        document['gdsc_derived'] = [attr.split(';') for attr in document['gdsc_derived']]

    # check for loaded variables
    loaded_variables = call_etl_api("postgis","gdsc_get_loaded_variables_for_table",{"table_id": document['gdsc_tablename'][0]})
    if GAIA_CATALOG_FLAVOR == "gdsc-api": loaded_variables = loaded_variables.split()[2:-2]
    
    # get json_ld 
    with open(f"/data/{name_id}/meta_json-ld_{name_id}.json", 'r', encoding='utf-8') as f:
        json_ld = json.load(f)

    # render page
    return render_template(
        'detail.html',
        name_id=name_id, 
        document=document, 
        loaded_variables=loaded_variables, 
        referrer=request.args,
        json_ld=json_ld
    )


@app.route('/loadlayer/<layer_id>', methods=["GET","POST"])
def loadlayer(layer_id):
    """
    load a layer given an id from the catalog
    """

    # check if layer is already loaded
    loaded_tables = call_etl_api("postgis","gdsc_get_schema_tables",{"schema_name": "public"})
    if GAIA_CATALOG_FLAVOR == "gdsc-api": loaded_tables = loaded_tables.split()[2:-2]
    if layer_id in loaded_tables: return {'already loaded': layer_id}

    # check for dependencies and load recursively if needed
    response = call_etl_api("postgis","gdsc_path_and_dependencies",{"table_id": layer_id})
    response = response.split(" ") if GAIA_CATALOG_FLAVOR == "gdsc-api" else response.split("\n")
    for layer in response[1:]: loadlayer(layer)
    data_path = response[0]

    # prepare response and get the ETL scripts
    response = {'load': layer_id}
    scripts = os.listdir(f'{data_path}/etl/')
    scripts = [x.split('_')[-1][:-3] for x in scripts if x not in ['processStep','.DS_Store'] and 'derivative' not in x]

    # run the ETL scripts
    for api in apis:
        if api in scripts:
            response[api] = call_etl_api(api,"gdsc_exec",{"shell": apis[api]['shell'], "script": f"{data_path}/etl/{layer_id}_{api}"})

    return response


@app.route('/load/<layer_id>/<variable_id>', methods=["GET","POST"])
def load(layer_id,variable_id):
    """
    py:function:: load(layer_id,variable_id)

    Load one variable given a variable_id. 

    :param str layer_id: the ID for the layer for the variable
    :param str variable_id: the ID for the variable to be loaded
    :return: the response body as dict from the postgres API
    :rtype: dict
    """

    def make_iso_date(date_string):
        """
        validates if a time string matches the expected format pattern.
        """
        try:
            datetime.strptime(date_string, "%m/%d/%y")
            return datetime.strptime(date_string,"%m/%d/%y").strftime("%Y-%m-%d")
        except ValueError:
            # assumes it is already iso
            return datetime.strptime(date_string,"%Y-%m-%d").strftime("%Y-%m-%d")

    # make sure the source layer is loaded
    load_layer = loadlayer(layer_id)

    # get the layer and variable metadata from SOLR
    document = get_layer_meta(layer_id)
    variable = [attr for attr in document['gdsc_attributes'] if variable_id in attr][0].split(";")  
    variable = [var if var !='' else 'Null' for var in variable]

    # construct and make request
    #parameters = "' '".join(variable[:-1])
    #payload = (
    #    f"\n{apis['postgis']['shell']} load_variable.sh "
    #    f"{layer_id} '{document['dct_description'][0]}' '{document['locn_geometry'][0]}' '{document['gdsc_label'][0]}' "
    #    f"'{'Null' if 'gdsc_nodata' not in document else document['gdsc_nodata'][1]}' '{parameters}'\n\n"
    #).encode('utf-8')
    parameters = {
        "params": {
            "table_id": layer_id,
            "table_description": document['dct_description'][0],
            "geom_type": document['locn_geometry'][0],
            "geom_label": document['gdsc_label'][0],
            "variable_nodata": 'Null' if 'gdsc_nodata' not in document else document['gdsc_nodata'][1],
            "variable_id": variable[0],
            "description": variable[1],
            "source": variable[2],
            "type": variable[3],
            "unit": variable[4],
            "unit_concept_id": None if variable[5] == "Null" else int(variable[5]),
            "min_val": None if variable[6] == "Null" else float(variable[6]),
            "max_val": None if variable[7] == "Null" else float(variable[7]),
            "start_date": make_iso_date(variable[8]),
            "end_date": make_iso_date(variable[9]),
            "concept_id": None if variable[10] == "Null" else int(variable[10])
        }
    }
    response = call_etl_api("postgis","gdsc_load_variable",parameters)

    return response


##
 # always get the list of collections for reference
 ##

COLLECTIONS, COLLECTIONS_COUNT = query_solr(
    'http://gaia-solr:8983/solr/collections/select?wt=json&',
    {
      "q.op": "OR",
      "q": "Status:published"
    }
)
keys = [item['CollectionID'][0] for item in COLLECTIONS]
COLLECTIONS = dict(zip(keys, COLLECTIONS))
COLLECTIONS = OrderedDict(sorted(COLLECTIONS.items(), key=lambda i: i[0].lower()))


##
 # run the app if called from the command line
 ##

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True,use_reloader=True,port=5000)