#!/usr/bin/env bash
set -e

easyrsa_dir=/etc/easy-rsa
server_keys_dir=/etc/openvpn/server/keys


build_pki() {
    echo 'PKI initialization'
    run_easyrsa init-pki

    echo 'Generate the Certificate Authority (CA) Certificate and Key'
    EASYRSA_REQ_CN="OpenVPN CA" run_easyrsa build-ca nopass

    echo 'Generate Diffie Hellman Parameters'
    run_easyrsa gen-dh

    echo 'Generate OpenVPN Server Certificate and Key'
    run_easyrsa build-server-full server nopass

    echo 'Generate Hash-based Message Authentication Code (HMAC) key'
    # to prevent DoS attacks and UDP port flooding
    openvpn --genkey secret ./pki/ta.key

    echo 'Generate OpenVPN Revocation Certificate'
    run_easyrsa gen-crl
}


run_easyrsa() {
  EASYRSA_BATCH=1 ./easyrsa "$@" > /dev/null 2> >(sed -n '/^Easy-RSA error:/,//p' >&2)
}


cd "$easyrsa_dir" || exit 1


if [[ ! -f ./pki/ca.crt ]]
then
    build_pki
fi


if [[ ! -d "$server_keys_dir" ]] || \
   [[ -z "$(find "$server_keys_dir" -mindepth 1 -print -quit)" ]]
then
    echo 'Copy Server Certificates and Keys to Server Config Directory'
    mkdir -p "$server_keys_dir"
    cp -rp ./pki/{ca.crt,dh.pem,ta.key,crl.pem,issued/server.crt,private/server.key} \
           "$server_keys_dir"
fi


if [[ ! -f ./pki/issued/client.crt ]] && \
   [[ ! -f ./pki/private/client.key ]] && \
   [[ ! -f ./pki/reqs/client.req ]]
then
    echo 'Generate OpenVPN Client Certificates and Keys'
    client-util generate client
fi
