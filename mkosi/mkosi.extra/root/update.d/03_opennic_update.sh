#!/usr/bin/env bash

set -e

apiUrl='https://api.opennicproject.org/geoip/?bare&ipv=4&res=10'
confFile=${1:-'result/opennic.conf'}

echo -n 'Update OpenNIC DNS servers...'

echo 'return {' > "$confFile"
curl -s "$apiUrl" | fping | awk '$3 == "alive" {print "\"" $1 "\","}' >> "$confFile"
echo '}' >> "$confFile"

echo '[OK]'

exit 0
