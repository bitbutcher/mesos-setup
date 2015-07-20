#!/usr/bin/env bash

mongo --eval 'JSON.stringify(rs.status());' --quiet | jq '.myState' | grep -qe '[12]'
