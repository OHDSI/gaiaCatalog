# start from an official solr base image
FROM solr

USER root

# copy the empty solr indices
COPY ./docker/solr/metadata/ /var/solr/data
RUN chown -R solr:solr /var/solr/data

# copy the catalog entries
COPY ./datastore/ /catalog

# copy the init script
COPY --chown=solr --chmod=0500 ./docker/solr/init.sh /init.sh

USER solr

ENTRYPOINT /init.sh
