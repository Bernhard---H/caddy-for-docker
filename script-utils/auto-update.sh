#!/usr/bin/env bash

WORK_DIR=$(pwd)
echo "Working directory: $WORK_DIR"

# find all container IDs for a given compose file:
echo "found compose projects: "
declare -A composeInfos
for composeFile in $(find "$WORK_DIR" -type f \( -name compose.yaml -o -name compose.yml -o -name docker-compose.yaml -o -name docker-compose.yml \) -exec realpath {} \; ); do
    project=$(dirname -- "${composeFile}")
    echo "${project}"
    composeInfos["${project}"]=$(docker compose --project-directory "${project}" ps --format "{{.ID}}"  | tr '\n' ' ')
done
echo ""

# iterate over the container to be upated:
for containerId in $(docker container ls --filter "label=at.grub1.auto-update=image" --quiet); do
    echo "updating container: $containerId"
    for project in ${!composeInfos[@]}; do
	for projectCId in ${composeInfos["${project}"]}; do
            if [ "${containerId,,}" = "${projectCId,,}" ]; then
                echo "found: ${project} -  ${projectCId}"

		service=$(docker container inspect "$containerId" --format "{{index .Config.Labels \"com.docker.compose.service\" }}")
                docker compose --project-directory "$project" pull "$service"
                docker compose --project-directory "$project" up -d "$service"

                break 2;
	    fi
        done
	echo "not found in project: $project"
    done
done

echo "done"
