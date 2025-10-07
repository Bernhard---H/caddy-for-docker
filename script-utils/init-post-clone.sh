#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_DIR=$(realpath -- "${SCRIPT_DIR}/..")
# sanity-check $REPO_DIR path:
if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "the calculated value of \$REPO_DIR seems to be wrong: ${REPO_DIR}"
    exit 1;
fi
if [ ! -f "${REPO_DIR}/.git/config" ]; then
    echo "the calculated value of \$REPO_DIR seems to be wrong: ${REPO_DIR}"
    exit 1;
fi
if ! grep -q "Bernhard---H/caddy-config.git" "${REPO_DIR}/.git/config"; then
    echo "the calculated value of \$REPO_DIR seems to be wrong: ${REPO_DIR}"
    exit 1;
fi
# success -> $REPO_DIR seems to be as expected

defaultConf="${REPO_DIR}/defaults"
localConf="$(realpath "${REPO_DIR}/../caddy")"

if [ ! -d "${localConf}" ]; then
    echo "creating local config dir"
    mkdir "${localConf}"
    chown root:root "${localConf}"
    chmod 0755 "${localConf}"
    touch "${localConf}/.gitkeep"
fi

if [ ! -d "${localConf}/secrets" ]; then
    echo "creating local config dir: secrets"
    mkdir "${localConf}/secrets"
    chown root:root "${localConf}/secrets"
    chmod 0755 "${localConf}/secrets"
    touch "${localConf}/secrets/.gitkeep"
fi
if [ ! -f "${localConf}/secrets/caddy.env" ]; then
    echo "creating local secrets files"
    cp "${defaultConf}/caddy.env" "${localConf}/secrets/"
    cp "${defaultConf}/secrets.gitignore" "${localConf}/secrets/.gitignore"
    chown root:root "${localConf}/secrets/caddy.env"
    chmod 0600 "${localConf}/secrets/caddy.env"
fi

if [ ! -d "${localConf}/apps" ]; then
    echo "creating local config dir: apps"
    mkdir "${localConf}/apps"
    chown root:root "${localConf}/apps"
    chmod 0755 "${localConf}/apps"
    touch "${localConf}/apps/.gitkeep"
fi

if [ ! -d "${localConf}/sites-available" ]; then
    echo "creating local config dir: sites-available"
    mkdir "${localConf}/sites-available"
    chown root:root "${localConf}/sites-available"
    chmod 0755 "${localConf}/sites-available"
    touch "${localConf}/sites-available/.gitkeep"
fi

if [ ! -d "${localConf}/sites-enabled" ]; then
    echo "creating local config dir: sites-enabled"
    mkdir "${localConf}/sites-enabled"
    chown root:root "${localConf}/sites-enabled"
    chmod 0755 "${localConf}/sites-enabled"
    touch "${localConf}/sites-enabled/.gitkeep"
fi

if [ ! -d "${localConf}/imports" ]; then
    echo "creating local config dir: imports"
    mkdir "${localConf}/imports"
    chown root:root "${localConf}/imports"
    chmod 0755 "${localConf}/imports"
    touch "${localConf}/imports/.gitkeep"
fi

if [ ! -d "${REPO_DIR}/local-config" ]; then
    echo "creating link to local config dir"
    ln -s "${localConf}/" "${REPO_DIR}/local-config"
fi


if [ ! -L "/etc/cron.daily/caddy-daily" ]; then
    echo "setup automatic execution of caddy-daily script using cron-jobs"
    ln -s "${REPO_DIR}/script-utils/caddy-daily.sh" "/etc/cron.daily/caddy-daily"
fi


# load network.env variables:
if [ -f "${REPO_DIR}/.network.env" ]; then
    echo "loading local initial network config"
    export $(grep --invert-match '#' "${REPO_DIR}/.network.env" | xargs)
else
    echo "loading default network config"
    export $(grep --invert-match '#' "${defaultConf}/network.env" | xargs)

    echo "safe initial caddy networking config"
    cp "${defaultConf}/network.env" "${REPO_DIR}/.network.env"
    if ! git diff --exit-code "${defaultConf}/network.env"; then
        echo "restoring defaults"
        git checkout HEAD -- "${defaultConf}/network.env"
    fi
fi

docker network inspect caddy > /dev/null 2>&1 || {
    echo "create docker network \"caddy\"";
    docker network create --driver bridge --subnet "10.17.0.0/16" --gateway "10.17.255.254" --ipv6=false caddy
}

apt-get -yqq install jq yq

echo "all done."