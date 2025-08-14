#!/usr/bin/env bash

echo "createIfNotExists docker network \"caddy\""
docker network inspect caddy > /dev/null 2>&1 || \
    docker network create --driver bridge --subnet "10.17.0.0/16" --gateway "10.17.255.254" --ipv6=false caddy

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -f "${SCRIPT_DIR}/caddy.env" ]; then
    echo "create local only config file .env"
    touch "${SCRIPT_DIR}/caddy.env"
    chown root:root "${SCRIPT_DIR}/caddy.env"
    chmod 0600 "${SCRIPT_DIR}/caddy.env"
fi

if [ ! -f "/etc/cron.daily/auto-stop-container" ]; then
    echo "setup auto-stop script"
    ln -s "${SCRIPT_DIR}/script-utils/auto-stop.sh" "/etc/cron.daily/auto-stop-container"
fi

if [ ! -f "/etc/cron.daily/auto-update-container" ]; then
    echo "setup auto-update script"
    ln -s "${SCRIPT_DIR}/script-utils/auto-update.sh" "/etc/cron.daily/auto-update-container"
fi

