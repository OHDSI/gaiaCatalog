from flask import Flask, Response, render_template, request, send_from_directory, url_for, make_response
from urllib.request import urlopen
from urllib.request import Request
from urllib import error
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

##
 # Globals
 ##

# set CONSTANTS
BASE_PATH='http://gaia-solr:8983/solr/dcat/select?wt=json&'
SNIP_LENGTH = 180
QUERY_FIELDS = ['gdsc_collections','dct_title','dcat_keyword','dct_description','gdsc_attributes']
DEFAULT_ROWS = 10
DEBUG = False

FILTER_SPECS = {
    "collections": {
        "field": "gdsc_collections_str",
        "facet_name": "possible_collections",
        "frontend_name": "Collections"
    },
    "keyword": {
        "field": "dcat_keyword_str",
        "facet_name": "possible_keywords",
        "frontend_name": "Keywords"
    },
    "geometry": {
        "field": "locn_geometry_str",
        "facet_name": "possible_geometries",
        "frontend_name": "Geometry"
    },
    "representation": {
        "field": "adms_representationTechnique_str",
        "facet_name": "possible_representations",
        "frontend_name": "Representation"
    }#,
#    "right": {
#        "field": "dct_rights_str",
#        "facet_name": "possible_rights",
#        "frontend_name": "Rights"
#    },
#    "active": {
#        "field": "gdsc_up",
#        "facet_name": "possible_activity",
#        "frontend_name": "Running"
#    }
}

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
api_call_order = ["git","gdsc","osgeo","postgis"]

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


##
 # helper functions for communication and formatting
 ##


def call_etl_api(api: str, func: str, params: dict) -> list:
    """
    py:function:: call_etl_api(api, func, params)

    call api on ETL containers to run func with provided parameters

    :param str api: the api to call
    :param str func: the function to request on the specified api
    :param dict params: the parameters to pass to the function
    :return: a list of the results
    :rtype: list
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


def get_layer_meta(layer_id: str) -> dict:
    """
    py:function:: get_layer_meta(layer_id)

    get SOLR dcat data for one layer

    :param str layer_id: the identifier for the layer
    :return: the dcat metadata for the layer
    :rtype: dict
    """

    query_parameters = {"q": "gdsc_tablename:" + layer_id}
    query_string  = urlencode(query_parameters)
    connection = urlopen("{}{}".format(BASE_PATH, query_string))
    response = simplejson.load(connection)
    document = response['response']['docs'][0]

    return document
    

def query_solr(path: str, parameters: dict, facet_field: str = None) -> tuple:
    """
    py:function:: query_solr(path, parameters)

    Query the SOLR API with an index for the catalog or collections.

    :param str path: the base url for the SOLR API
    :param dict parameters: the query parameters
    :param facet_field: optional field for which to get all possible options for froma all documents, if unspecified, query normally
    :return: the query results, the number of results
    :rtype: tuple
    """

    # Build the query string and url
    query_string = urlencode(parameters)
    url = f"{path}{query_string}"

    # Send the request
    try:
        with urlopen(url) as connection:
            response = simplejson.load(connection)
    except Exception as e:
        print(f"Error querying SOLR: {e}")
        return [], 0

    # Extract results
    if facet_field != None:
        if DEBUG: print('getting facets:')
        results = response.get('facet_counts', {}).get('facet_fields', {}).get(facet_field, [])
        numresults = len(results)
    else:
        if DEBUG: print('getting datasets:')
        numresults = response.get('response', {}).get('numFound', 0)
        results = response.get('response', {}).get('docs', [])

    if DEBUG: print(url)
    return results, numresults


def highlight_query(document: dict, query: str) -> dict:
    """
    py:function:: highlight_query(document, query)

    Highlight the query text in the given document.

    :param dict document: the document metadata
    :param str query: string to highlight in the document
    :return: the document metadata with css class elements added to html content in dict entries found in QUERY_FIELDS
    :rtype: dict
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


def build_citation(document: dict, type: str) -> str:
    """
    py:function:: build_citation(document, type)

    Create a formatted citation string for the document in the given format type.

    :param dict document: the document metadata
    :param str type: the format type ["bibtex", "ris"]
    :return: the formatted citation
    :rtype: str
    """

    cite_formats = {
        "formatters": {
            "bibtex": {
                "begin": "@misc{",
                "indent": "  ",
                "seperator": " = ",
                "quote_start": "{",
                "quote_end": "}",
                "line_seperator": ",",
                "end": "}"
            },
            "ris": {
                "begin": "TY  - DATA\n",
                "indent": "",
                "seperator": "  - ",
                "quote_start": "",
                "quote_end": "",
                "line_seperator": "",
                "end": "ER  - \n\n"
            }
        },
        "extension": {
            "bibtex": "bib",
            "ris": "ris"
        },
        "fields" : {
            "dct_creator": {
                "type": "list",
                "bibtex": "author",
                "ris": "AU"
            },
            "dct_issued": {
                "type": "date",
                "bibtex": "year",
                "ris": "PY"
            },
            "dct_title": {
                "type": "single",
                "bibtex": "title",
                "ris": "TI"
            },
            "dct_publisher": {
                "type": "single",
                "bibtex": "publisher",
                "ris": "PB"
            },
            "dct_identifier": {
                "type": "single",
                "bibtex": "url",
                "ris": "UR"
            },
            "dcat_keyword": {
                "type": "list",
                "bibtex": "keywords",
                "ris": "KW"
            },
            "dct_modified": {
                "type": "date",
                "bibtex": "timestamp",
                "ris": "Y2"
            },
            "dct_language": {
                "type": "single",
                "bibtex": "language",
                "ris": "LA"
            },
            "gdsc_version": {
                "type": "single",
                "ris": "WV"
            },
            "gdsc_collections": {
                "type": "single",
                "ris": "T3"
            }
        }
    }

    def build_element(field,value):
        return (
            f"{formatters['indent']}{field}{formatters['seperator']}"
            f"{formatters['quote_start']}{value}{formatters['quote_end']}"
            f"{formatters['line_seperator']}\n"
        )

    formatters = cite_formats['formatters'][type]
    entry = formatters['begin']
    if type == "bibtex":
        entry += f"{document['gdsc_tablename'][0]}\n" or "citation\n"

    formatters = cite_formats['formatters'][type]
    # looped citation body construction
    for dc_term in cite_formats['fields']:
        field = cite_formats['fields'][dc_term]
        if type in field:
            if dc_term in document:
                val = document[dc_term]       
                if field['type'] in ["single", "date"]:
                    if dc_term in ["dct_issued"]: val[0] = val[0][:4]
                    if dc_term in ["dct_modified"]: val[0] = val[0].split('T')[0]    
                    entry += build_element(field[type],val[0])
                elif field['type'] == "list":
                    for item in val:
                        entry += build_element(field[type],item.split(";")[0])

    entry += formatters['end']
    return entry


def fetch_facets(field: str, query: str, fq: str) -> tuple:
    """
    py:function:: fetch_facets(field: str, query: str, fq: str) -> tuple

    Fetch the facets from SOLR for a given field and return a tuple with the 
    results and the number of results.

    :return: the query results, the number of results
    :rtype: tuple
    """

    params = {
        "q": query,
        "q.op": "AND",
        "fq": fq,
        "defType": "edismax",
        "qf": ' '.join(QUERY_FIELDS),
        "facet.field": field,
        "indent": "true",
        "rows": "0",
        "facet": "true",
        "facet.mincount": "1",
        "facet.limit": "-1",
        "facet.sort": "count"
    }

    return query_solr(
        f'{BASE_PATH}/dcat/select?wt=json&',
        params,
        field
    )



##
 # Routes and views
 ##


@app.route('/', methods=["GET"])
def index() -> str:
    """
    py:function:: index()

    Render HTML for the top level route of the application.

    :return: HTML for the index page
    :rtype: str
    """

    collection = request.args.get("collection", "all")
    query = request.args.get("query", "")
    query = re.sub(r'[\+\-\&\|\!\(\)\{\}\[\]\^\"\~\*\?\:\\]','',query)
    page = int(request.args.get("page", 1))

    # --- Collect filters dynamically ---
    selected_filters = {
        key: request.args.getlist(key)
        for key in FILTER_SPECS
    }

    # --- Base query ---
    q = query or "*"

    fq_parts = []

    if collection == "all":
        fq_parts.append("gdsc_collections:*")
    else:
        fq_parts.append(f'gdsc_collections:"{collection}"')

    # --- Apply programmatic filters ---
    for key, values in selected_filters.items():
        if len(values) > 0:
            field = FILTER_SPECS[key]["field"]
            clauses = [f'{field}:"{v}"' for v in values]
            clause = f"({' AND '.join(clauses)})"
            fq_parts.append(clause)

    fq = " ".join(fq_parts)

    # --- Solr query ---
    query_parameters = {
        "q.op": "AND",
        "defType": "edismax",
        "fq": fq,
        "q": q,
        "qf": ' '.join(QUERY_FIELDS),
        "start": (page - 1) * DEFAULT_ROWS,
        "rows": DEFAULT_ROWS
    }

    results, numresults = query_solr(
        f'{BASE_PATH}/dcat/select?wt=json&',
        query_parameters
    )

    # --- Post-processing ---
    for entry in results:

        if query:
            entry = highlight_query(entry, query)

        if entry.get('dct_description'):
            desc = entry['dct_description'][0]
            entry['display_description'] = (
                desc[:SNIP_LENGTH] + '...'
                if len(desc) > SNIP_LENGTH else desc
            )

    if collection == "*":
        collection = "all"

    # --- Fetch facet values dynamically ---
    facet_data = {}
    for key, spec in FILTER_SPECS.items():
        values, count = fetch_facets(spec["field"], q, fq)
        if key == "collections":
            facet_data[spec["facet_name"]] = [
                y for i in range(0,int(len(values)/2)) if values[i*2] in COLLECTIONS \
                for y in (values[i*2], values[i*2+1])
            ]
        else:
            facet_data[spec["facet_name"]] = values

    # check for loaded tables
    loaded_tables = call_etl_api("postgis","gdsc_get_schema_tables",{"schema_name": "public"})
    if GAIA_CATALOG_FLAVOR == "gdsc-api": loaded_tables = loaded_tables.split()[2:-2]

    # --- Render ---
    return render_template(
        "index.html",
        collection=collection,
        query=query,
        page=page,
        results=results,
        numresults=numresults,
        collections=COLLECTIONS,
        filter_specs=FILTER_SPECS,
        root="./",
        facet_data=facet_data,
        loaded_tables=loaded_tables,
        selected_filters=selected_filters
    )


@app.route('/detail/<name_id>', methods=["GET","POST"])
def detail(name_id: str) -> str:
    """
    py:function:: detail(name_id)

    Query SOLR for one document and render the metadata detail page for one dataset.

    :param str name_id: the unique identifier for the dataset (tablename)
    :return: HTML for the detail page
    :rtype: str
    """

    args = request.args.to_dict()

    # query solr
    document = get_layer_meta(name_id)

    # highlight query if exists
    if "query" in args:
        if args['query'] != None and args['query'] != 'None' and args['query'] != '':
            document = highlight_query(document,args['query'])
    else: args['query'] = None

    # structure results for display
    if 'gdsc_attributes' in document:
        document['gdsc_columns'] = [attr.split(';')[0] for attr in document['gdsc_attributes']]
    if 'gdsc_attributes' in document:
        document['gdsc_attributes'] = [attr.split(';') for attr in document['gdsc_attributes']]
    if 'gdsc_derivatives' in document:
        document['gdsc_derived'] = [attr.split(';') for attr in document['gdsc_derived']]

    # check for loaded tables
    loaded_tables = call_etl_api("postgis","gdsc_get_schema_tables",{"schema_name": "public"})
    if GAIA_CATALOG_FLAVOR == "gdsc-api": loaded_tables = loaded_tables.split()[2:-2]

    # check for loaded variables
    loaded_variables = call_etl_api("postgis","gdsc_get_loaded_variables_for_table",{"table_id": document['gdsc_tablename'][0]})
    if GAIA_CATALOG_FLAVOR == "gdsc-api": loaded_variables = loaded_variables.split()[2:-2]
 
    # get json_ld 
    try:
        with open(f"/data/{name_id}/meta_json-ld_{name_id}.json", 'r', encoding='utf-8') as f:
            json_ld = json.load(f)
    except:
        json_ld = ""

    # render page
    return render_template(
        'detail.html',
        name_id=name_id, 
        document=document, 
        loaded_variables=loaded_variables,
        loaded_tables=loaded_tables,
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
    for api in api_call_order:
        if api in scripts:
            try:
                response[api] = call_etl_api(api,"gdsc_exec",{"shell": apis[api]['shell'], "script": f"{data_path}/etl/{layer_id}_{api}"})
            except error.HTTPError as e:
                e = loads(e.read().decode('utf-8'))
                if e['code'] == "XX000": response[api] = e['message']
                else: raise
            except Exception as err:
                print(f"Other error occurred: {err}")

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
    parameters = {
        "params": {
            "table_id": layer_id,
            "table_description": document['dct_description'][0],
            "geom_type": document['locn_geometry'][0],
            "geom_label": document['gdsc_label'][0],
            "variable_nodata": "" if 'gdsc_nodata' not in document else document['gdsc_nodata'][1],
            "variable_id": variable[0],
            "description": variable[1].strip('"'),
            "source": variable[2],
            "type": variable[3],
            "unit": variable[4],
            "unit_concept_id": "" if variable[5] == "Null" else int(variable[5]),
            "min_val": "" if variable[6] == "Null" else float(variable[6]),
            "max_val": "" if variable[7] == "Null" else float(variable[7]),
            "start_date": make_iso_date(variable[8]),
            "end_date": make_iso_date(variable[9]),
            "concept_id": "" if variable[10] == "Null" else int(variable[10])
        }
    }
    response = call_etl_api("postgis","gdsc_load_variable",parameters)

    return response

@app.route('/bibliography/<collection>/<fmt>', methods=["GET"])
@app.route('/cite/<table_id>/<fmt>', methods=["GET"])
def cite(collection: str = None, table_id: str = None, fmt: str = None) -> Response:
    """
    py:function:: cite(collection, table_id, fmt)

    Create a set of correctly formatted citations and return as a (Flask) Response.

    :param str collection: the unique identifier for the collection
    :param str table_id: the unique identifier for the dataset (tablename)
    :param str fmt: the citation format identifier 
    :return Response: correctly formatted citations as a (Flask) Response
    :rtype: Response
    """

    # Normalize parameters
    name_id = table_id  # reuse variable name for clarity

    # Build query parameters
    if name_id:
        query_parameters = {"q": f"gdsc_tablename:{name_id}"}
    elif collection:
        if collection == "all":
            query_parameters = {"q": "*:*"}
        else:
            query_parameters = {"q": f"gdsc_collections:{collection}"}
    else:
        return {"error": "Please provide either 'collection' or 'table_id'."}, 400

    documents, numresults = query_solr(f"{BASE_PATH}/dcat/select?wt=json&", query_parameters)
    if not documents:
        return {"error": "No documents found."}, 400

    # Generate output
    if fmt in ["bibtex", "ris"]:
        citations = [build_citation(doc, fmt) for doc in documents]
        output = ''.join(citations)
        filename = (name_id or collection or "citations") + f".{fmt}"
    else:
        return {"error": f"Unsupported format '{fmt}'."}, 400

    # Build response
    resp = make_response(output)
    resp.headers["Content-Disposition"] = f"attachment; filename={filename}"
    resp.headers["Content-Type"] = "text/plain"
    return resp


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