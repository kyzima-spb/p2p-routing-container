#!/usr/bin/env bash

set -e

url='https://kyzima-spb.github.io/p2p-routing-container/include-hosts-custom.txt'
hostsFile=${1:-'config/include-hosts-custom.txt'}
tempFile="$(mktemp)"

echo -n 'Update custom hosts...'
( curl -s "$url"; echo '' ; cat "$hostsFile" ) | sort -u | grep -v '^\s*$' > "$tempFile"
mv "$tempFile" "$hostsFile"
echo '[OK]'

exit 0
