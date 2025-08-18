#!/usr/bin/env bash

# P2P Routing Container for Debian based OS installation script

set -e

NAME=${NAME:-'p2p'}
IMAGE=${IMAGE:-'https://kyzima-spb.github.io/p2p-routing-container/images/default/rootfs.tar.xz'}


function next_filename()
{
	filename="$1"

	name="${filename%%.*}"
	ext="${filename#*.}"
	number=1

	while [ -e "$filename" ]
	do
		filename="${name}_$(( number++ )).${ext}"
	done

	echo "$filename"
}


function backupCredentials()
{
    local name=$1
    local backupFile=${2:-"${name}-backup.tar.xz"}
    backupFile="$(next_filename "$backupFile")"

	if ! systemd-nspawn -q --pipe --private-network -M "$name" -U tar -cPJO \
		/etc/openvpn/server/keys/ca.crt \
		/etc/openvpn/server/keys/antizapret-server.crt \
		/etc/openvpn/server/keys/antizapret-server.key \
		/root/easy-rsa-ipsec/CLIENT_KEY/antizapret-client-tcp.ovpn \
		/root/easy-rsa-ipsec/CLIENT_KEY/antizapret-client-udp.ovpn \
		/root/easy-rsa-ipsec/easyrsa3/pki \
		> "$backupFile"
	then
		rm -f "$backupFile"
		return 1
	fi

	echo >&2 "OpenVPN credentials saved to ${backupFile}"
}


function restoreCredentials() {
    local name=$1
    local backupFile=$2

    if [[ -z "$backupFile" ]]
    then
		echo >&2 'BACKUP_FILE required.'
    	return 1
	fi

	systemd-nspawn -q --pipe --private-network -M "$name" -U tar -C / -xPJf - < "$backupFile"

	echo >&2 "OpenVPN credentials restored from ${backupFile}"
}


function installRequirements()
{
	local publicKeys=(
		0xEF2E2223D08B38D4B51FFB9E7135A006B28E1285 # Default
		0xA2AFF7EB363E6C8DD27655AD62CD962F89DDC0CD # My
	)

	apt update -qq

	if ! command -v machinectl > /dev/null
	then
		DEBIAN_FRONTEND=noninteractive apt install -qq -y systemd-container
	fi

	if ! command -v gpg > /dev/null
	then
		DEBIAN_FRONTEND=noninteractive apt install -qq -y gnupg
	fi

	gpg -k > /dev/null

	for key in "${publicKeys[@]}"
	do
		gpg \
			--no-default-keyring \
			--keyring /etc/systemd/import-pubring.gpg \
			--keyserver hkps://keyserver.ubuntu.com \
			--receive-keys "$key"
	done

	systemctl enable --now systemd-networkd.service
}


function install()
{
	local name="$1"
	local image="$2"

	if [[ -f "$image" ]]
	then
		machinectl import-tar "$image" "$name"
	else
		machinectl pull-tar "$image" "$name"
	fi

	local nspawnDir="/etc/systemd/nspawn"
	local nspawnFile="${nspawnDir}/${name}.nspawn"

	mkdir -p "$nspawnDir"
	
	if [[ ! -f "$nspawnFile" ]]
	then
		cat > "$nspawnFile" <<- EOF
			[Exec]
			NotifyReady=yes

			[Network]
			VirtualEthernet=yes
			Port=tcp:1194:1194
			Port=udp:1194:1194
		EOF
	fi

	machinectl enable "$name"
	machinectl start "$name"

	src="/root/easy-rsa-ipsec/CLIENT_KEY/antizapret-client-tcp.ovpn"
	target="$(next_filename "${name}.ovpn")"
	
	echo -n "Wait creation OVPN config file."

	while ! machinectl copy-from "$name" "$src" "$target" 2>/dev/null
	do
		echo -n '.'
		sleep 1
	done

	echo "[OK]"
	echo "OpenVPN configuration file saved to ${target}"
	
	chown "$SUDO_UID:$SUDO_GID" "$target"
}


function uninstall
{
	local name="$1"

	if machinectl show "$name" > /dev/null
	then
		machinectl poweroff "$name"
	fi

	if machinectl show-image "$name" > /dev/null
	then
		machinectl disable "$name"

		while ! machinectl remove "$name" 2>/dev/null
		do
			sleep 1
		done
	fi

	rm -f "/etc/systemd/nspawn/${name}.nspawn"
}


main()
{
	if [ "$(whoami)" != 'root' ]
	then
		echo >&2 "You have no permission to run $0 as non-root user. Use sudo"
		exit 1
	fi

	case "$COMMAND" in
		backup)
			backupCredentials "$NAME" "$BACKUP_FILE" ;;
		restore)
			restoreCredentials "$NAME" "$BACKUP_FILE" ;;
		install|'')
			installRequirements
			install "$NAME" "$IMAGE" ;;
		uninstall)
			uninstall "$NAME" ;;
		*)
			echo >&2 'Command not found'
			exit 1
			;;
	esac
}


main "$@"
