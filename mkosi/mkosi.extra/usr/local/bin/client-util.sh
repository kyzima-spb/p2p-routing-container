#!/usr/bin/env bash
set -e

easyrsa_dir=/etc/easy-rsa
server_keys_dir=/etc/openvpn/server/keys


generate_client() {
  local name="$1"
  local revoke="${2:-false}"

  if $revoke; then
    revoke_client "$name"
  fi

  echo "Generate certificate and key for client: $name"
  run_easyrsa build-client-full "$name" nopass
}


get_remote_ip() {
    local services=(2ip.ru icanhazip.com ifconfig.me api.ipify.org)

    for url in "${services[@]}"; do
      curl -sf -4 --connect-timeout 10 "$url" && break
    done
}


revoke_client() {
  local name="$1"

  echo "Revocation of a previously issued certificate for a client: $name"
  run_easyrsa revoke "$name"

  echo 'Generate OpenVPN Revocation Certificate'
  run_easyrsa gen-crl

  echo "Copying the CRL file to the OpenVPN server directory: $server_keys_dir"
  cp ./pki/crl.pem "$server_keys_dir"/

  echo 'Restarting OpenVPN server'
  systemctl restart openvpn-server@server
}


run_easyrsa() {
  EASYRSA_BATCH=1 ./easyrsa "$@" > /dev/null 2> >(sed -n '/^Easy-RSA error:/,//p' >&2)
}


show_config() {
  # Arguments: name, format, remote, password, port, proto
  local name="$1"
  declare -n kwargs=$2
  local output_format="${kwargs[format]:-ovpn}"
  local password="${kwargs[password]}"

  if [[ ! -f "./pki/issued/${name}.crt" ]] || [[ ! -f "./pki/private/${name}.key" ]]
  then
    echo >&2 "Invalid argument value: client with '$name' not found."
    exit 1
  fi

  local CA_CERT CLIENT_CERT CLIENT_KEY
  CA_CERT="$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' ./pki/ca.crt)"
  CLIENT_CERT="$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "./pki/issued/${name}.crt")"

  if [[ -f "./pki/private/${name}.key" ]]
  then
    CLIENT_KEY="$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' "./pki/private/${name}.key")"
  else
    CLIENT_KEY='<!-- YOUR PRIVATE KEY -->'
  fi

  export PROTO="${kwargs[proto]:-udp}"
  export REMOTE="${kwargs[remote]:-$(get_remote_ip)}"
  export REMOTE_PORT="${kwargs[port]:-1194}"
  export CA_CERT
  export CLIENT_CERT
  export CLIENT_KEY

  if [[ -n "$password" ]]
  then
    output_format='zip'
  fi

  case "$output_format" in
    ovpn)
      envsubst < "/etc/openvpn/templates/client-${PROTO}.tmpl"
      ;;
    zip)
      local tmpdir
      tmpdir="$(mktemp -d)"
      # shellcheck disable=SC2064
      trap "rm -r '$tmpdir'" EXIT

      envsubst < "/etc/openvpn/templates/client-${PROTO}.tmpl" > "$tmpdir/client.ovpn"

      declare zip_args=(
        -qj
        -
        ./pki/ca.crt
        ./pki/ta.key
        "./pki/issued/${name}.crt"
        "./pki/private/${name}.key"
        "$tmpdir/client.ovpn"
      )

      [[ -n "$password" ]] && zip_args+=(-P "$password")

      zip "${zip_args[@]}"
      ;;
    *)
      echo >&2 "Invalid argument value: unknown format '$format'."
      exit 1
      ;;
  esac
}


usage() {
	case "$1" in
		generate)
			cat 1>&2 <<-ENDOFUSAGE

			Adds a new OpenVPN client

			Usage: $(basename "$0") $1 NAME [OPTIONS]"

			Positional:
			  NAME STRING           CN (name) of the client

			Options:
			  -f --revoke BOOL      Recreate the client, overwriting the old private key and certificate

			ENDOFUSAGE
			;;
		revoke)
			cat 1>&2 <<-ENDOFUSAGE

			Revokes a previously issued certificate to a client

			Usage: $(basename "$0") $1 NAME [OPTIONS]"

			Positional:
			  NAME STRING           CN (name) of the client

			Options:


			ENDOFUSAGE
			;;
		show)
			cat 1>&2 <<-ENDOFUSAGE

			Outputs to STDOUT the OVPN configuration file for the client with the given CN

			Usage: $(basename "$0") $1 NAME [OPTIONS]"

			Positional:
			  NAME STRING           CN (name) of the client

			Options:
			  --format STRING       OVPN file or zip archive, default - ovpn
			                        Allowed values: ovpn, zip
			  -r --ip
			     --remote STRING    OpenVPN server host, default - external IP address
			  --password STRING     Password for archive, default - not set
			  -p --port STRING      OpenVPN server port, default - 1194
			  --proto STRING        Server connection protocol, default - udp
			                        Allowed values: udp, tcp

			ENDOFUSAGE
			;;
		*)
			cat 1>&2 <<-ENDOFUSAGE

			Utility for working with keys and certificates

			Usage: $(basename "$0") COMMAND NAME [OPTIONS]

			Commands:
			  generate  Create a new client
			  revoke    Revokes the client certificate
			  show      Show ovpn file for client

			ENDOFUSAGE
			;;
	esac
}


case "$1" in
  '')
    usage
    exit 1
    ;;
  -h|--help)
    usage
    exit
    ;;
  -v|--version)
    echo 'Not implemented :)'
    exit
    ;;
  generate|revoke|show)
    cmd="$1"
    shift
    ;;
  *)
    echo >&2 "Unknown command: $1"
    usage
    exit 1
    ;;
esac

declare -A options_map=()
declare -A flags_map=()

case "$cmd" in
  generate)
    flags_map+=(
      [-f]="revoke"
      [--revoke]="revoke"
    )
    ;;
  show)
    options_map+=(
      [--format]="format"
      [-r]="remote"
      [--ip]="remote"
      [--remote]="remote"
      [--password]="password"
      [-p]="port"
      [--port]="port"
      [--proto]="proto"
    )
    ;;
esac

declare cli_positional=()
declare -A cli_options=()

while [[ "$#" -gt 0 ]]
do
  case "$1" in
    -h|--help)
      usage "$cmd"
      exit 0
      ;;
    --*|-*)
      if [[ -v "options_map[$1]" ]]; then
        cli_options["${options_map[$1]}"]="$2"
        shift 2
      elif [[ -v "flags_map[$1]" ]]; then
        cli_options["${flags_map[$1]}"]=true
        shift 1
      else
        echo >&2 "Error: Unknown option $1"
        usage
        exit 1
      fi
      ;;
    *)
      cli_positional+=("$1")
      shift
      ;;
  esac
done

name="${cli_positional[0]}"

if [[ -z "$name" ]]; then
    echo >&2 "Required positional argument: name"
    usage "$cmd"
    exit 1
fi

cd "$easyrsa_dir" || exit 1

case "$cmd" in
  generate)
    generate_client "$name" "${cli_options[revoke]}"
    ;;
  revoke)
    revoke_client "$name"
    ;;
  show)
    show_config "$name" cli_options
    ;;
esac
