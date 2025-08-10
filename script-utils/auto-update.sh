#!/usr/bin/env bash

WORK_DIR=$(dirname -- "${BASH_SOURCE[0]}")

# find all container IDs for a given compose file:
declare -A composeInfos
for composeFile in $(find "$WORK_DIR" -type f \( -name compose.yaml -o -name compose.yml -o -name docker-compose.yaml -o -name docker-compose.yml \) -exec realpath {} \; ); do
    project=$(dirname -- "${composeFile}")
    composeInfos["${project}"]=$(docker compose --project-directory "${project}" ps --format "{{.ID}}"  | tr '\n' ' ')
done

# iterate over the container to be upated:
for containerId in $(docker container ls --filter "label=at.grub1.auto-update=image" --quiet); do
    echo "updating container: $containerId"
    for project in ${composeInfos[@]}; do
        for projectCId in "${composeInfos["${project}"][@]}"; do
            echo "${project} -  ${projectCId}"
        done
    done
done

echo "done"
