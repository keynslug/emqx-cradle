#!/bin/env sh

set -o errexit

while ! curl -sSf 'http://emqx.dev:18083/' ; do
    sleep 1
done

curl -sSf 'http://emqx.dev:18083/api/v5/login' \
    -H 'Authorization: Bearer undefined' \
    -H 'Content-Type: application/json' \
    --data-raw '{"username":"admin","password":"public"}' > login.json

curl -sSf 'http://emqx.dev:18083/api/v5/users/admin/change_pwd' \
    -H "Authorization: Bearer $(cat login.json | jq -r .token)" \
    -H 'Content-Type: application/json' \
    --data-raw '{"new_pwd":"'${EMQX_ADMIN_PASSWORD}'","old_pwd":"public"}'
