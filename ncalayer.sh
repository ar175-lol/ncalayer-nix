#!/usr/bin/env bash
set -euo pipefail

JRE="@JRE@"
JAR="@JAR@"
PCSC_LIB="@PCSC_LIB@"
NCALAYER_LIBPATH="@LD_LIBRARY_PATH@:@JRE@/lib/amd64"

if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
	export LD_LIBRARY_PATH="$NCALAYER_LIBPATH:$LD_LIBRARY_PATH"
else
	export LD_LIBRARY_PATH="$NCALAYER_LIBPATH"
fi

NCALAYER_DATA_DIRS="@XDG_DATA_DIRS@:/run/current-system/sw/share"
if [[ -n "${XDG_DATA_DIRS:-}" ]]; then
	export XDG_DATA_DIRS="$NCALAYER_DATA_DIRS:$XDG_DATA_DIRS"
else
	export XDG_DATA_DIRS="$NCALAYER_DATA_DIRS"
fi

version() {
	echo "NCALayer 1.4"
}

usage() {
	cat <<-EOF
		Usage:
		  ncalayer            start NCALayer
		  ncalayer --stop     stop the running NCALayer (systemd unit if present)
		  ncalayer --restart  restart NCALayer
		  ncalayer --version  print version
		  ncalayer --help     show this help
	EOF
}

stop() {
	if systemctl --user is-active ncalayer.service >/dev/null 2>&1; then
		systemctl --user stop ncalayer.service
	else
		pkill -f -- "-jar ${JAR}" 2>/dev/null || true
	fi
}

restart() {
	if systemctl --user restart ncalayer.service 2>/dev/null; then
		exit 0
	fi
	pkill -f -- "-jar ${JAR}" 2>/dev/null || true
	sleep 1
	exec "$JRE/bin/java" -Dsun.security.smartcardio.library="$PCSC_LIB" -jar "$JAR" "$@"
}

case "${1:-}" in
	--help | -h)
		usage
		exit 0
		;;
	--version | -v)
		version
		exit 0
		;;
	--stop)
		stop
		exit 0
		;;
	--restart)
		shift || true
		restart "$@"
		;;
esac

exec "$JRE/bin/java" -Dsun.security.smartcardio.library="$PCSC_LIB" -jar "$JAR" "$@"