#!/usr/bin/env bash

set -e

cp result/opennic.conf /etc/knot-resolver/
cp result/knot-aliases-alt.conf /etc/knot-resolver/
systemctl restart kresd@1.service

cp result/openvpn-blocked-ranges.txt /etc/openvpn/server/ccd/DEFAULT
nft flush set inet filter azvpnwhitelist
while read -r line
do
    nft add element inet filter azvpnwhitelist "{ $line }"
done < result/blocked-ranges.txt

exit 0
