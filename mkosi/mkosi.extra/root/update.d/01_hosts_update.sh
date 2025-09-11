#!/usr/bin/env bash

set -e

url='https://kyzima-spb.github.io/p2p-routing-container/include-hosts-custom.txt'
custom_hosts_file=${1:-'config/include-hosts-custom.txt'}
temp_file="$(mktemp)"

# shellcheck disable=SC2064
trap "rm -f $temp_file" EXIT

echo -n 'Update custom hosts...'

url_list="$(
  curl -sf --fail-early --compressed -4 --connect-timeout 10 "$url" || true;
  echo '' ;
  cat &2>/dev/null "$custom_hosts_file" || true
)"

if [[ -n "$url_list" ]]
then
  echo "$url_list" | sort -u | grep -v '^\s*$' > "$temp_file"
  mv "$temp_file" "$custom_hosts_file"
  echo '[OK]'
else
  echo '[ERROR]'
fi

exit 0
