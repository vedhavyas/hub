#!/bin/zsh
function extract_exec() {
    exec=$1
    dst=$2
    id=$(docker create vedhavyas/"${exec}":latest)
    rm -rf "${dst}"
    docker cp "$id":/app/"${exec}" "${dst}"
    docker rm -v "$id"
}

echo "extracting archiver..."
extract_exec archiver /sbin/hub-script-archiver
