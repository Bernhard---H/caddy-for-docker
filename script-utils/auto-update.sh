#!/usr/bin/env bash

# iterate over the container to be upated:
while IFS= read -r labelsObject; do
    projectDir=$(jq -r '.["com.docker.compose.project.working_dir"]' <<<$labelsObject)
    serviceName=$(jq -r '.["com.docker.compose.service"]' <<<$labelsObject)
    echo "updating: $serviceName of project: $projectDir"

    docker compose --project-directory "$projectDir" pull "$serviceName"
    docker compose --project-directory "$projectDir" up -d "$serviceName"
done <<< "$(docker container inspect --format "{{json .Config.Labels}}" $(docker container ls --filter "label=at.grub1.auto-update=image" --quiet))"

echo "done updating, starting cleanup: "
docker image prune -f -a --filter "until=24h"

