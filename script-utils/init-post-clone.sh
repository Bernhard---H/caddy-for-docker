#!/usr/bin/env bash

DO_UPGRADE=false
for arg in "$@"; do
    case "$arg" in
        -u|--upgrade) DO_UPGRADE=true ;;
        -h|--help)    echo "usage: $0 [-u|--upgrade]"; exit 0 ;;
        *)            >&2 echo "unknown argument: $arg"; exit 64 ;;
    esac
done


SCRIPT_DIR=$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)
REPO_DIR=$(realpath -- "${SCRIPT_DIR}/..")
# sanity-check $REPO_DIR path:
#echo "repository git-dir: ${REPO_DIR}/.git"
if ( ! test -d "${REPO_DIR}/.git" ); then
    >&2 echo "the calculated value of \$REPO_DIR seems to be wrong: ${REPO_DIR}"
    exit 1;
fi
if [ ! -f "${REPO_DIR}/.git/config" ]; then
    >&2 echo "the calculated value of \$REPO_DIR seems to be wrong: ${REPO_DIR}"
    exit 2;
fi
if ! grep -q "Bernhard---H/caddy-for-docker.git" "${REPO_DIR}/.git/config"; then
    >&2 echo "the calculated value of \$REPO_DIR seems to be wrong: ${REPO_DIR}"
    exit 3;
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
    ln -s "${REPO_DIR}/script-utils/daily.sh" "/etc/cron.daily/caddy-daily"
fi

apt-get -yqq install jq

function genULA() {
    # info: https://en.wikipedia.org/wiki/Unique_local_address
    # source: https://stackoverflow.com/a/34329057
    hexdump -vn5 -e '1/1 "fd%02x:" 2/2 "%04x:" 1 "1::/64"' /dev/random
}

function printIpv6Required() {
    local daemonJson='{"ipv6":true,"fixed-cidr-v6":"'
    daemonJson="${daemonJson}$(genULA)\"}"
    {
        echo "Please enable IPv6 of the docker-engine for this host:"
        echo ""
        echo "Ammend or create the file: /etc/docker/daemon.json"
        echo "  using this JSON Sippet: "
        echo "$daemonJson" | jq '.'
        echo ""
        echo "source: https://docs.docker.com/engine/daemon/ipv6/#use-ipv6-for-the-default-bridge-network"
    } >&2
}

# examples: fd12:3456:789a::/64  fd12:3456:789a:1::/64
readonly ULA_CIDR_RE='^([0-9a-f]{1,4}):([0-9a-f]{1,4}):([0-9a-f]{1,4})(:([0-9a-f]{1,4}))?::/64$'

function extractDockerCidr() {
    [ -f /etc/docker/daemon.json ] || return 0
    jq -r '.["fixed-cidr-v6"] // empty' /etc/docker/daemon.json 2>/dev/null | tr 'A-F' 'a-f'
}

# true (0), iff daemon.json provides a usable fixed-cidr-v6
function hostHasIPv6() {
    [[ "$(extractDockerCidr)" =~ $ULA_CIDR_RE ]]
}

function genCaddySubnet() {
    local cidr subnetId
    cidr=$(extractDockerCidr)
    if [[ ! "$cidr" =~ $ULA_CIDR_RE ]]; then
        printIpv6Required
        return 1
    fi
    subnetId=$(( 16#${BASH_REMATCH[5]:-0} + 1 ))
    if (( subnetId > 0xffff )); then
        >&2 echo "no free IPv6 subnet id left after ${cidr}"
        return 1
    fi
    printf '%s:%s:%s:%x' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" \
        "${BASH_REMATCH[3]}" "$subnetId"
}

function editVar() {
    local varName="$1"
    local varValue="$2"

    sed "s|^${varName}=.*|${varName}=${varValue}|"
}

function genDefaultsIPv4() {
    cat "${defaultConf}/network.env"
}

function genDefaultsIPv6() {
    local prefix
    prefix=$(genCaddySubnet) || return 1

    cat "${defaultConf}/network.ipv6.env" \
        | editVar CADDY_IPv6_SUBNET "${prefix}::/64" \
        | editVar CADDY_IPv6_IPRANGE "${prefix}:1::/80" \
        | editVar CADDY_IPv6_GATEWAY "${prefix}::1" \
        | editVar CADDY_IPv6_APP_CONTAINER "${prefix}::2"
}

function genEnvFile() {
    genDefaultsIPv4 || return 1
    if hostHasIPv6; then
        echo
        genDefaultsIPv6 || return 1
    else
        >&2 echo "WARN: no IPv6 config found in /etc/docker/daemon.json, setting up legacy IPv4-only mode."
    fi
}

function confirmUpgrade() {
    >&2 echo "docker network caddy is running in legacy mode."
    # for non interactive mode: disable upgrades
    [ -t 0 ] || return 1
    local answer
    read -r -p "Upgrade now? containers will be briefly disconnected. [y/N] " answer
    [[ "$answer" =~ ^[yY]$ ]]
}

function envHasIPv6() {
    grep -q '^CADDY_IPv6_SUBNET=.\+' "${REPO_DIR}/.env"
}

function migrateEnv() {
    local ipv6conf
    ipv6conf=$(genDefaultsIPv6) || return 1
    echo "migrating local caddy network config: adding IPv6 config"
    chattr -i "${REPO_DIR}/.env"
    chmod 0644 "${REPO_DIR}/.env"
    { echo; echo "$ipv6conf"; } >> "${REPO_DIR}/.env"
    chmod 0444 "${REPO_DIR}/.env"
    chattr +i "${REPO_DIR}/.env"
}

function caddyLsAttached() {
    docker container ls -a -q --filter "network=caddy"
}

function caddyCreator() {
    echo "create docker network \"caddy\""
    local args=(--driver bridge --ipv4=true
        --subnet "${CADDY_IPv4_SUBNET}" --gateway "${CADDY_IPv4_GATEWAY}"
        --ip-range "${CADDY_IPv4_IPRANGE}")
    if [ -n "${CADDY_IPv6_SUBNET:-}" ]; then
        args+=(--ipv6=true --subnet "${CADDY_IPv6_SUBNET}"
            --gateway "${CADDY_IPv6_GATEWAY}" --ip-range "${CADDY_IPv6_IPRANGE}")
    fi
    docker network create "${args[@]}" caddy
}

# true (0), iff network exists and config is up to date
function caddyIsUpToDate() {
    docker network inspect caddy >/dev/null 2>&1 || return 1

    local ipv6 subnets
    subnets=$(docker network inspect caddy \
        --format '{{range .IPAM.Config}}{{.Subnet}}{{"\n"}}{{end}}')
    grep -qxF "${CADDY_IPv4_SUBNET}" <<< "$subnets" || return 1

    # Legacy-Modus: kein IPv6 konfiguriert -> nichts zu upgraden
    [ -n "${CADDY_IPv6_SUBNET:-}" ] || return 0

    ipv6=$(docker network inspect caddy --format '{{.EnableIPv6}}')
    [ "$ipv6" = "true" ] || return 1
    grep -qxF "${CADDY_IPv6_SUBNET}" <<< "$subnets" || return 1
    return 0
}

function caddyReconnect() {
    local backupDir="$1" id a ip4
    shift
    for id in "$@"; do
        [ -n "$id" ] || continue
        local args=()
        while IFS= read -r a; do
            args+=(--alias "$a")
        done < <(jq -r --arg id "$id" \
            '.Aliases // [] | .[] | select(. != ($id | .[0:12]))' \
            "${backupDir}/${id}.json")
        ip4=$(jq -r '.IPAMConfig.IPv4Address // empty' "${backupDir}/${id}.json")
        [ -n "$ip4" ] && args+=(--ip "$ip4")
        docker network connect "${args[@]}" caddy "$id" \
            || >&2 echo "WARNING: could not reconnect ${id}"
    done
}

function caddyUpgrade() {
    local backupDir ids id
    backupDir=$(mktemp -d)
    echo "backup of old network config: ${backupDir}"

    # 1. create backup (complete caddy entwork + config of each caddy container)
    docker network inspect caddy > "${backupDir}/network.json"
    mapfile -t ids < <(caddyLsAttached)
    for id in "${ids[@]}"; do
        [ -n "$id" ] || continue
        docker inspect "$id" \
            --format '{{json (index .NetworkSettings.Networks "caddy")}}' \
            > "${backupDir}/${id}.json"
    done

    # 2. disconnect contianers,
    for id in "${ids[@]}"; do
        [ -n "$id" ] || continue
        docker network disconnect -f caddy "$id"
    done
    #   delete the IPv4 caddy network
    if ! docker network rm caddy; then
        >&2 echo "could not remove network, rolling back"
        caddyReconnect "$backupDir" "${ids[@]}"
        return 1
    fi
    #   and create a new IPv6 caddy network
    caddyCreator || { >&2 echo "recreate failed, backup in ${backupDir}"; return 1; }}

    # 3. restore old docker network connections from backup
    caddyReconnect "$backupDir" "${ids[@]}"
}

#echo "early exit"; exit 0;


envOutdated=false
if [ ! -f "${REPO_DIR}/.env" ]; then
    echo "setup initial caddy networking config"
    createEnvFile > "${REPO_DIR}/.env" || { rm -f "${REPO_DIR}/.env"; exit 4; }
    chmod 0444 "${REPO_DIR}/.env"
    chattr +i "${REPO_DIR}/.env"
elif ! envHasIPv6; then
    if hostHasIPv6; then
        envOutdated=true
    fi
    printIpv6Required
fi
echo "loading local caddy networking config"
set -a; source "${REPO_DIR}/.env"; set +a

netExists=false
netOutdated=false
if docker network inspect caddy >/dev/null 2>&1; then
    netExists=true
    caddyIsUpToDate || netOutdated=true
fi

if $envOutdated || $netOutdated; then
    if $DO_UPGRADE || confirmUpgrade; then
        if $envOutdated; then
            migrateEnv || exit 4
            # load IPv6 variables
            set -a; source "${REPO_DIR}/.env"; set +a
        fi
        if $netExists; then
            caddyUpgrade || exit 5
        else
            caddyCreator || exit 5
        fi
    else
        >&2 echo "WARNING: caddy docker-network is running in legacy mode (IPv4 only)."
        >&2 echo "run '$0 --upgrade' to enable IPv6."
        # create network in legacy (IPv4-only) mode
        $netExists || caddyCreator || exit 5
    fi
elif ! $netExists; then
    caddyCreator || exit 5
else
    echo "network caddy is up to date"
fi

echo "all done."