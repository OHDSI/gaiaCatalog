from flask import Flask, render_template, request, send_from_directory
from urllib.request import urlopen
from urllib.request import Request
from urllib.parse import urlencode
from os import getenv
from json import loads
import simplejson
import logging
import re
from collections import OrderedDict
import os

app = Flask(__name__)
log = logging.getLogger('werkzeug')
log.disabled = True

X_API_KEY_FILE = getenv('GAIA_X_API_KEY_FILE')
with open(X_API_KEY_FILE) as f:
    X_API_KEY = f.read().strip()
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
    }
}
headers = {
    "x-api-key": X_API_KEY,
    "Content-Type": "application/octet-stream"
}

BASE_PATH='http://gaia-solr:8983/solr/dcat/select?wt=json&'
SNIP_LENGTH = 180
QUERY_FIELDS = ['gdsc_collections','dct_title','dcat_keyword','dct_description','gdsc_attributes']

##
 # get solr data
 ##
def query_solr(path,parameters):

    numresults = 1
    results = []

    # send query to SOLR and gather paged results
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

##
 # highlight found instances of query in document metadata
 ##
def highlight_query(document,query):

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
                    for term in terms:
                        document[field][i] = add_tags(document[field][i],term)
                    row = attr.split(';')
                    if len(row) > 1:
                        document[field][i] = add_tags(document[field][i],row[0]) 
                        for j in range(0,2):
                            for term in terms:
                                row[j] = add_tags(row[j],term)
                        row[0] = add_tags(row[0],row[0])
                        attrs.append([row[0],row[1]])
            if len(attrs) > 0: document['found_in'][field] = attrs

    return document

##
 # run SOLR query and render results for main page
 ##
@app.route('/', methods=["GET","POST"])
def index():
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
        query = re.sub(r'[\+\-\&\|\!\(\)\{\}\[\]\^\"\~\*\?\:\\]','',args["searchTerm"])
        if query == "None" or query == "": query = None
        collection = args["collection"]
        if 'active' in args:
            active = args["active"]
            if active == 'None': active = None

        # build the query parameters for SOLR
        if collection == 'all' or collection == '*':
            collection = '*'
        q = f"+gdsc_collections:{collection}"
        if query is not None:
            q += f" (" 
            for field in QUERY_FIELDS:
                q += f"{field}:*{query}* OR "
            q = f"{q[:-4]})" 
        if active is not None:
            q += " +gdsc_up:true"
        query_parameters = {
          "q.op": "AND",
          "defType": "lucene",
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

    if collection == "*": collection = 'all'

    return render_template(
        'index.html',
        collection=collection,
        query=query,
        active=active,
        numresults=numresults,
        results=results,
        collections=COLLECTIONS
    )

##
 # query SOLR for one document and render all metadata in detail
 ##
@app.route('/detail/<name_id>', methods=["GET","POST"])
def detail(name_id):

    args = request.args.to_dict()

    query_parameters = {"q": "gdsc_tablename:" + name_id}
    query_string  = urlencode(query_parameters)
    connection = urlopen("{}{}".format(BASE_PATH, query_string))
    response = simplejson.load(connection)
    document = response['response']['docs'][0]

    if 'gdsc_attributes' in document:
        document['gdsc_columns'] = [attr.split(';')[0] for attr in document['gdsc_attributes']]

    if args['query'] != None and args['query'] != 'None' and args['query'] != '':
        document = highlight_query(document,args['query'])

    if 'gdsc_attributes' in document:
        document['gdsc_attributes'] = [attr.split(';') for attr in document['gdsc_attributes']]

    if 'gdsc_derivatives' in document:
        document['gdsc_derived'] = [attr.split(';') for attr in document['gdsc_derived']]

    return render_template('detail.html', name_id=name_id, document=document, referrer=request.args)

##
 # load layer
 ##
@app.route('/loadlayer/<layer_id>', methods=["GET","POST"])
def loadlayer(layer_id):

    response = {'load': layer_id}
    scripts = os.listdir(f'/data/data/{layer_id}/etl/')
    scripts = [x.split('_')[-1][:-3] for x in scripts if x not in ['processStep','.DS_Store']]

    for api in apis:
        if api in scripts:
            payload = f"\n{apis[api]['shell']} /data/{layer_id}/etl/{layer_id}_{api}.sh\n\n".encode('utf-8')
            req = Request(apis[api]['url'], data=payload, headers=headers, method='POST')
            resp = urlopen(req).read()
            output = loads(resp.decode('utf-8').strip(),strict=False)
            response[api] = output['res']

    return response

##
 # load variable
 ##
@app.route('/load/<variable_id>', methods=["GET","POST"])
def load(variable_id):

    query_parameters = {"variable_id": variable_id[5:]}
    query_string  = urlencode(query_parameters) 
    connection = urlopen("http://gaia-core:8000/load?{}".format(query_string))                                             
    response = simplejson.load(connection)

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
keys = [item['Collection_ID'][0] for item in COLLECTIONS]
COLLECTIONS = dict(zip(keys, COLLECTIONS))
COLLECTIONS = OrderedDict(sorted(COLLECTIONS.items(), key=lambda i: i[0].lower()))

##
 # run the app if called from the command line
 ##
if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True,use_reloader=True,port=5000)