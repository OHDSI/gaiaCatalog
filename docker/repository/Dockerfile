# Start from an official Python base image.
FROM python:3.9.16-alpine3.17

# copy the init script
RUN mkdir -p /docker-entrypoint-init
COPY ./docker/repository/init.sh /docker-entrypoint-init
RUN chmod 0500 /docker-entrypoint-init/init.sh

ENV USER=ohdsi
ENV GROUPNAME=$USER
ENV UID=1001
ENV GID=1002

# Install basic web server tools and create non-root user
RUN addgroup --gid "$GID" "$GROUPNAME" && \
    adduser --disabled-password --ingroup "$GROUPNAME" --uid "$UID" $USER

# Set the user and current working directory to /ohdsi.
USER ohdsi
WORKDIR /ohdsi

# set up the python environment
COPY ./docker/repository/requirements.txt ./
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# copy the app
COPY ./docker/repository/ohdsi.py ./
COPY ./docker/repository/static ./static
COPY ./docker/repository/templates ./templates
CMD ["sleep","infinity"]