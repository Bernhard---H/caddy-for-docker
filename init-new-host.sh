#!/usr/bin/env bash

echo "create docker network \"caddy\""
docker network inspect caddy > /dev/null 2>&1 || \
    docker network create --driver bridge --subnet "10.17.0.0/16" --gateway "10.17.255.254" --ipv6=false caddy


echo "create local only config file .env"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

touch "${SCRIPT_DIR}/caddy.env"
chown root:root "${SCRIPT_DIR}/caddy.env"
chmod 0600 "${SCRIPT_DIR}/caddy.env"


echo "setup auto-stop script"
ln -s "${SCRIPT_DIR}/script-utils/auto-stop.sh" "/etc/cron.daily/auto-stop-container"

