#!/usr/bin/env bash

# inspired by: https://github.com/mholt/caddy-l4/issues/16#issuecomment-1742044526

set -e

cp -a /etc/caddy/. /conf/

caddy fmt /conf/Caddyfile --overwrite || true
caddy adapt --config /conf/Caddyfile --pretty --validate > /conf/caddy.json

jsonVars=""
jqOp=""

if [ -d "/conf/apps" ] && [ -n "$(ls -A /conf/apps)" ]; then
    for fileName in /conf/apps/*.json; do

        appName="$(basename "$fileName" ".json" | tr ' ' '_')"
        jsonVars="${jsonVars} --slurpfile ${appName} $fileName"
        if [[ -n "${jqOp}" ]]; then
            jqOp="${jqOp} |" 
        fi
        jqOp="${jqOp} .apps.${appName} = \$${appName}[0]"
    done

    set -x
    jq $jsonVars "$jqOp" /conf/caddy.json > /tmp/caddy.json
    set +x
    mv /tmp/caddy.json /conf/caddy.json
    cat /conf/caddy.json
fi

caddy run --config /conf/caddy.json "$@"

