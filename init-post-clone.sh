#!/usr/bin/env bash

echo "createIfNotExists docker network \"caddy\""
docker network inspect caddy > /dev/null 2>&1 || \
    docker network create --driver bridge --subnet "10.17.0.0/16" --gateway "10.17.255.254" --ipv6=false caddy

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

defaultConf="${SCRIPT_DIR}/defaults"
localConf="$(realpath "${SCRIPT_DIR}/../caddy")"

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

if [ ! -d "${SCRIPT_DIR}/local-config" ]; then
    echo "creating link to local config dir"
    ln -s "${localConf}/" "${SCRIPT_DIR}/local-config"
fi


if [ ! -f "/etc/cron.daily/auto-stop-container" ]; then
    echo "setup auto-stop script"
    ln -s "${SCRIPT_DIR}/script-utils/auto-stop.sh" "/etc/cron.daily/auto-stop-container"
fi

if [ ! -f "/etc/cron.daily/auto-update-container" ]; then
    echo "setup auto-update script"
    ln -s "${SCRIPT_DIR}/script-utils/auto-update.sh" "/etc/cron.daily/auto-update-container"
fi

