#!/bin/bash

set -e
set -u

owner=${OWNER:-owner}
database=${DATABASE:-database}
docker exec -it postgres psql -U postgres -c \
"CREATE USER $owner; CREATE DATABASE $database; GRANT ALL PRIVILEGES ON DATABASE $database TO $owner;"
