#!/usr/bin/env bash

source '/mongo_entry.sh'

#curl -s -X GET "http://127.0.0.1:8500/v1/catalog/service/mongo?tag=identity&tag=black" | jq -c -M '[.[] | "\(.Address):\(.ServicePort)" ]'


# register service via HTTP
#curl -s -X PUT /v1/catalog/register
