#!/bin/env bash

set -o errexit
set -o pipefail

CWD="$(dirname "$0")"
SCRIPTNAME=$(basename "$0")

COMPOSE=${COMPOSE:-"docker-compose"}

USAGE=$(cat <<EOF
Fire up a docker-compose setup with specific redis / emqx configuration.
Usage: ${SCRIPTNAME}
  [ --redis=(single | single+mtls | single+toxiproxy | cluster | sentinel) ]
  [ --emqx=(single | cluster) ]
  [ --conf=<extra-emqx-config-file> ]
EOF
)

function usage {
    echo -e "$USAGE"
    exit 127
}

TEMP=$(getopt -o "" --longoptions help,redis:,emqx:,conf: -n "$SCRIPTNAME" -- "$@")
[ $? != 0 ] && usage

eval set -- "$TEMP"

CONFIG_REDIS="single"
CONFIG_EMQX="single"

COMPOSE_CONFIGS=("-f compose/network.yml")
COMPOSE_EXTRAENV=()
EMQX_CONFIGS=()
EMQX_EXTRA_CONFIGS=()

while true; do
  case "${1}" in
    --help  ) usage ;;
    --redis ) CONFIG_REDIS="${2}" ; shift 2 ;;
    --emqx  ) CONFIG_EMQX="${2}" ; shift 2 ;;
    --conf  ) EMQX_EXTRA_CONFIGS+=("${2}") ; shift 2 ;;
    --      ) shift 1 ; break ;;
    *       ) usage ;;
  esac
done

case "${CONFIG_REDIS}" in
  single )
    COMPOSE_CONFIGS+=("-f compose/redis-single.yml") ;
    EMQX_CONFIGS+=("config/bridge-redis-single.conf") ;;
  single+mtls )
    COMPOSE_CONFIGS+=("-f compose/redis-single.yml") ;
    COMPOSE_EXTRAENV+=("REDIS_TLS_AUTH_CLIENTS=yes") ;
    EMQX_CONFIGS+=("config/bridge-redis-single-mtls.conf") ;;
  single+toxiproxy )
    COMPOSE_CONFIGS+=(
      "-f compose/redis-single.yml"
      "-f compose/toxiproxy.yml") ;
    EMQX_CONFIGS+=(
      "config/bridge-redis-single.conf"
      "config/bridge-redis-single-proxy.conf"
      "config/bridge-redis-single-mtls.conf"
      "config/bridge-redis-single-tls-proxy.conf"
      ) ;;
  cluster )
    COMPOSE_CONFIGS+=("-f compose/redis-cluster.yml") ;;
  sentinel )
    COMPOSE_CONFIGS+=("-f compose/redis-sentinel.yml") ;;
  * )
    usage ;;
esac

case "${CONFIG_EMQX}" in
  single      ) COMPOSE_CONFIGS+=("-f compose/emqx-single.yml") ;;
  cluster     ) COMPOSE_CONFIGS+=("-f compose/emqx-cluster.yml") ;;
  *           ) usage ;;
esac

for c in ${EMQX_EXTRA_CONFIGS[@]}; do
  [ -f "${c}" ] || usage
  EMQX_CONFIGS+=("${c}")
done

for i in ${!EMQX_CONFIGS[@]}; do
  COMPOSE_EXTRAENV+=("EMQX_EXTRA_CONFIG_${i}=../${EMQX_CONFIGS[$i]}")
done

echo "env ${COMPOSE_EXTRAENV[@]} ${COMPOSE} ${COMPOSE_CONFIGS[@]} up --remove-orphans \$@" | tee "up.sh"
echo "env ${COMPOSE_EXTRAENV[@]} ${COMPOSE} ${COMPOSE_CONFIGS[@]} down \$@" | tee "down.sh"
echo "env ${COMPOSE_EXTRAENV[@]} ${COMPOSE} ${COMPOSE_CONFIGS[@]} \$@" > "do.sh"

chmod +x "up.sh" "down.sh" "do.sh"
ls -la "up.sh" "down.sh" "do.sh"
