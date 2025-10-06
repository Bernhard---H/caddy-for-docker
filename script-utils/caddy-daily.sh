#!/usr/bin/env bash

echo "looking for containers to auto-stop:"
containerIDs=$(docker container ls --filter "label=at.grub1.auto-stop" --quiet | tr '\n' ' ')
if [[ -n $containerIDs ]]; then
    docker container stop $containerIDs
fi

echo "looking for container to auto-update their image:"
while IFS= read -r labelsObject; do
    projectDir=$(jq -r '.["com.docker.compose.project.working_dir"]' <<<$labelsObject)
    serviceName=$(jq -r '.["com.docker.compose.service"]' <<<$labelsObject)
    echo "    updating: $serviceName of project: $projectDir"

    # pull new image and deploy:
    docker compose --project-directory "$projectDir" pull "$serviceName"
    docker compose --project-directory "$projectDir" up -d "$serviceName"
done <<< "$(docker container inspect --format "{{json .Config.Labels}}" $(docker container ls --filter "label=at.grub1.auto-update=image" --quiet))"

echo "looking for container to auto-update their built Dockerfile build:"
while IFS= read -r labelsObject; do
    projectDir=$(jq -r '.["com.docker.compose.project.working_dir"]' <<<$labelsObject)
    serviceName=$(jq -r '.["com.docker.compose.service"]' <<<$labelsObject)
    echo "    updating: $serviceName of project: $projectDir"

    # pull new base image, build new image and deploy:
    docker compose --project-directory "$projectDir" build --pull "$serviceName"
    docker compose --project-directory "$projectDir" up -d "$serviceName"
done <<< "$(docker container inspect --format "{{json .Config.Labels}}" $(docker container ls --filter "label=at.grub1.auto-update=build" --quiet))"

echo "starting image cleanup (at least 24h old): "
docker image prune -f -a --filter "until=24h"

echo "all done."