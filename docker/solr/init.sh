#!/bin/bash

set -e
cd /opt/solr-9.8.1-slim/

# Custom Solr start script
    
# Set Solr options
SOLR_OPTS="-Djetty.host=0.0.0.0"

# Start Solr in the foreground
echo "[gaia-solr] Starting Solr with custom configuration..."
./bin/solr start $SOLR_OPTS

# wait for SOLR to become ready
SOLR_BASE="http://localhost:8983/solr/"
SOLR_URL="${SOLR_BASE}admin/info/system?wt=json"
MAX_ATTEMPTS=30
WAIT_SECONDS=2

echo "[gaia-solr] Waiting for SOLR to become ready"
for i in $(seq 1 $MAX_ATTEMPTS); do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SOLR_URL")
  if [ "$RESPONSE" = "200" ]; then
    echo "[gaia-solr] Solr is ready!"

		# remove any pre-existing indexes
		echo "[gaia-solr] Removing any old indexes"
		curl -g "${SOLR_BASE}collections/update" -d '<delete><query>*:*</query></delete>'
		curl -g "${SOLR_BASE}dcat/update" -d '<delete><query>*:*</query></delete>'

		# build the indexes for collections and data respectively
		echo "[gaia-solr] Indexing the collections"
		./bin/solr post --solr-url http://localhost:8983 -c collections -filetypes json $(find /catalog/collections -name 'meta_*.json' -type f)
		./bin/solr post --solr-url http://localhost:8983 -c dcat -filetypes json $(find /catalog/data -name 'meta_dcat*.json' -type f)

		echo "[gaia-solr] Solr index initialized"
		break
  fi
  
  echo "[gaia-solr] Error: Solr failed to become ready in time (HTTP $RESPONSE). Attempt $i/$MAX_ATTEMPTS. Retrying in ${WAIT_SECONDS}s ..."
  sleep $WAIT_SECONDS
done

if [[ i -ge $MAX_ATTEMPTS ]]; then
  echo "[gaia-solr] Error: Solr failed to become ready in time."
  exit 1
fi

# leave the container waiting
tail -f /dev/null