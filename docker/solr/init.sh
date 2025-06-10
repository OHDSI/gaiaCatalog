#!/bin/bash

set -e
cd /opt/solr-9.8.1/

# Custom Solr start script
    
# Set Solr options
SOLR_OPTS="-Djetty.host=0.0.0.0"

# Start Solr in the foreground
echo "Starting Solr with custom configuration..."
./bin/solr start $SOLR_OPTS

# arbitrary wait for solr to start
sleep 5

# remove any pre-existing indexes
curl -g 'http://localhost:8983/solr/collections/update' -d '<delete><query>*:*</query></delete>'
curl -g 'http://localhost:8983/solr/dcat/update' -d '<delete><query>*:*</query></delete>'

# build the indexes for collections and data respectively
echo "indexing the collections"
./bin/solr post --solr-url http://localhost:8983 -c collections -filetypes json $(find /catalog/collections -name 'meta_*.json' -type f)
./bin/solr post --solr-url http://localhost:8983 -c dcat -filetypes json $(find /catalog/data -name 'meta_dcat*.json' -type f)

# leave the container waiting
tail -f /dev/null