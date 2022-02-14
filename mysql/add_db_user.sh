#!/bin/bash

set -e
set -u

owner=${OWNER:-owner}
database=${DATABASE:-database}
docker exec -it mysql mysql -h 127.0.0.1 -P 3306 -u root -p -e \
"CREATE USER $owner; CREATE DATABASE $database; GRANT ALL PRIVILEGES ON $database.* TO $owner; FLUSH PRIVILEGES;"
