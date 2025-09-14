#!/bin/bash
# Added a comment to force Docker cache invalidation
# shellcheck disable=SC2317
# Don't warn about unreachable commands in this file

set -Eeo pipefail

echo "DEBUG: Script starting as user $(id -u) ($(id -un))"

# If TWS_SETTINGS_PATH is set, ensure the user owns it
if [ -n "${TWS_SETTINGS_PATH}" ]; then
  echo "DEBUG: TWS_SETTINGS_PATH is set to ${TWS_SETTINGS_PATH}"
  echo "DEBUG: Permissions BEFORE chown:"
  ls -la "${TWS_SETTINGS_PATH}" || true # Use || true to prevent script from exiting if dir doesn't exist
  chown -R ${USER_ID}:${USER_GID} "${TWS_SETTINGS_PATH}"
  echo "DEBUG: Permissions AFTER chown:"
  ls -la "${TWS_SETTINGS_PATH}" || true
fi

# If we are running as root, drop privileges and re-execute this script as the ibgateway user
if [ "$(id -u)" = '0' ]; then
	# Fix permissions for tws_settings and jts.ini before dropping privileges
	if [ -d "/home/ibgateway/tws_settings" ]; then
		echo "DEBUG: Fixing permissions for /home/ibgateway/tws_settings" >&2
		chown -R ${USER_ID}:${USER_GID} /home/ibgateway/tws_settings
		chmod -R u+rwX /home/ibgateway/tws_settings
		if [ -f "/home/ibgateway/tws_settings/jts.ini" ]; then
			echo "DEBUG: Fixing permissions for /home/ibgateway/tws_settings/jts.ini" >&2
			chown ${USER_ID}:${USER_GID} /home/ibgateway/tws_settings/jts.ini
			chmod u+rw /home/ibgateway/tws_settings/jts.ini
		fi
	fi
	echo "DEBUG: Running as root, dropping privileges to ibgateway (${USER_ID}:${USER_GID})" >&2
	sync
	exec gosu ibgateway "$0" "$@"
fi

echo "DEBUG: Script continuing as user $(id -u) ($(id -un))"

echo "DEBUG: Current permissions for /home/ibgateway/tws_settings and jts.ini after privilege drop:" >&2
ls -la /home/ibgateway/tws_settings 2>/dev/null || true
ls -la /home/ibgateway/tws_settings/jts.ini 2>/dev/null || true

echo "*************************************************************************"
echo ".> Starting IBC/IB gateway"
echo "*************************************************************************"

# shellcheck disable=SC1091
source "${SCRIPT_PATH}/common.sh"

stop_ibc() {
	echo ".> 😘 Received SIGINT or SIGTERM. Shutting down IB Gateway."

	#
	if pgrep x11vnc >/dev/null; then
		echo ".> Stopping x11vnc."
		pkill x11vnc
	fi
	#
	echo ".> Stopping Xvfb."
	pkill Xvfb
	#
	if [ -n "$SSH_TUNNEL" ]; then
		echo ".> Stopping ssh."
		pkill run_ssh.sh
		pkill ssh
		echo ".> Stopping socat."
		pkill run_socat.sh
		pkill socat
	else
		echo ".> Stopping socat."
		pkill run_socat.sh
		pkill socat
	fi
	# Set TERM
	echo ".> Stopping IBC."
	kill -SIGTERM "${pid[@]}"
	# Wait for exit
	wait "${pid[@]}"
	# All done.
	echo ".> Done... $?"
}

start_xvfb() {
	# start Xvfb
	echo ".> Starting Xvfb server"
	DISPLAY=:1
	export DISPLAY
	rm -f /tmp/.X1-lock
	Xvfb $DISPLAY -ac -screen 0 1024x768x16 &
}

start_vnc() {
	# start VNC server
	file_env 'VNC_SERVER_PASSWORD'
	if [ -n "$VNC_SERVER_PASSWORD" ]; then
		echo ".> Starting VNC server"
		x11vnc -ncache_cr -display :1 -forever -shared -bg -noipv6 -passwd "$VNC_SERVER_PASSWORD" &
		unset_env 'VNC_SERVER_PASSWORD'
	else
		echo ".> VNC server disabled"
	fi
}

start_IBC() {
	echo ".> Starting IBC in ${TRADING_MODE} mode, with params:"
	echo ".>		Version: ${TWS_MAJOR_VRSN}"
	echo ".>		program: ${IBC_COMMAND:-gateway}"
	echo ".>		tws-path: ${TWS_PATH}"
	echo ".>		ibc-path: ${IBC_PATH}"
	echo ".>		ibc-init: ${IBC_INI}"
	echo ".>		tws-settings-path: ${TWS_SETTINGS_PATH:-$TWS_PATH}"
	echo ".>		on2fatimeout: ${TWOFA_TIMEOUT_ACTION}"
	# start IBC -g for gateway
	"${IBC_PATH}/scripts/ibcstart.sh" "${TWS_MAJOR_VRSN}" -g \
		"--tws-path=${TWS_PATH}" \
		"--ibc-path=${IBC_PATH}" "--ibc-ini=${IBC_INI}" \
		"--on2fatimeout=${TWOFA_TIMEOUT_ACTION}" \
		"--tws-settings-path=${TWS_SETTINGS_PATH:-}" &
	_p="$!"
	pid+=("$_p")
	export pid
	echo "$_p" >"/tmp/pid_${TRADING_MODE}"
}

start_process() {
	# set API and socat ports
	set_ports
	# apply settings
	apply_settings
	# forward ports, socat/ssh
	port_forwarding

	start_IBC
}

###############################################################################
#####		Common Start
###############################################################################
# start Xvfb
start_xvfb

# setup SSH Tunnel
setup_ssh

# Java heap size
set_java_heap

# start VNC server
start_vnc

###############################################################################
#####		Paper, Live or both start process
###############################################################################

if [ "$TRADING_MODE" == "both" ] || [ "$DUAL_MODE" == "yes" ]; then
	# start live and paper
	DUAL_MODE=yes
	export DUAL_MODE
	# start live first
	TRADING_MODE=live
	# add _live subfix
	_IBC_INI="${IBC_INI}"
	export _IBC_INI
	IBC_INI="${_IBC_INI}_${TRADING_MODE}"
	if [ -n "$TWS_SETTINGS_PATH" ]; then
		_TWS_SETTINGS_PATH="${TWS_SETTINGS_PATH}"
		export _TWS_SETTINGS_PATH
		TWS_SETTINGS_PATH="${_TWS_SETTINGS_PATH}_${TRADING_MODE}"
	else
		# no TWS settings
		_TWS_SETTINGS_PATH="${TWS_PATH}"
		export _TWS_SETTINGS_PATH
		TWS_SETTINGS_PATH="${_TWS_SETTINGS_PATH}_${TRADING_MODE}"
	fi
fi

start_process

if [ "$DUAL_MODE" == "yes" ]; then
	# running dual mode, start paper
	TRADING_MODE=paper
	TWS_USERID="${TWS_USERID_PAPER}"
	export TWS_USERID

	# handle password for dual mode
	if [ -n "${TWS_PASSWORD_PAPER_FILE}" ]; then
		TWS_PASSWORD_FILE="${TWS_PASSWORD_PAPER_FILE}"
		export TWS_PASSWORD_FILE
	else
		TWS_PASSWORD="${TWS_PASSWORD_PAPER}"
		export TWS_PASSWORD
	fi
	# disable duplicate ssh for vnc/rdp
	SSH_VNC_PORT=
	export SSH_VNC_PORT
	# in dual mode, ssh remote always == api port
	SSH_REMOTE_PORT=
	export SSH_REMOTE_PORT
	#
	IBC_INI="${_IBC_INI}_${TRADING_MODE}"
	TWS_SETTINGS_PATH="${_TWS_SETTINGS_PATH}_${TRADING_MODE}"

	sleep 15
	start_process
fi

trap stop_ibc SIGINT SIGTERM
wait "${pid[@]}"
exit $?
