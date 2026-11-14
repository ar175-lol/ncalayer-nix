#!/usr/bin/env bash
set -euo pipefail

JRE="@JRE@"
JAR="@JAR@"
PCSC_LIB="@PCSC_LIB@"
INSTALL_CERTS="@INSTALL_CERTS@"
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

# Java 8 OpenJFX (libglassgtk3.so) and AWT/Swing are strictly X11 clients. Under
# Wayland, GTK 3 defaults to the Wayland backend where GDK_IS_X11_DISPLAY fails
# and XInternAtom segfaults. Force the X11 backend so it routes through Xwayland.
export GDK_BACKEND=x11

# Auto-detect X11 display when DISPLAY is unset (e.g. Wayland compositor with Xwayland).
if [[ -z "${DISPLAY:-}" ]]; then
	for sock in /tmp/.X11-unix/X*; do
		if [[ -S "$sock" ]]; then
			display_num="${sock##*/X}"
			export DISPLAY=":$display_num"
			break
		fi
	done
fi

if [[ -z "${DISPLAY:-}" ]]; then
	printf 'warning: DISPLAY is not set and no X11 socket was found in /tmp/.X11-unix\n' >&2
	printf 'warning: Java 8 requires an X11 server (e.g. xwayland-satellite on Niri) to display GUI dialogs\n' >&2
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

# Browsers create their NSS database when their first profile is opened, which
# is usually after the systemd certificate installer has already run. Refresh
# the trust store here as well so `nix run .#ncalayer` works without manual
# steps. Set NCALAYER_SKIP_CERT_INSTALL=1 to opt out.
maybe_install_certs() {
	if [[ -z "${NCALAYER_SKIP_CERT_INSTALL:-}" ]] && [[ -x "$INSTALL_CERTS" ]]; then
		"$INSTALL_CERTS" || true
	fi
}

stop() {
	if systemctl --user is-active ncalayer.service >/dev/null 2>&1; then
		systemctl --user stop ncalayer.service
	else
		pkill -f -- "-jar ${JAR}" 2>/dev/null || true
	fi
}

check_running() {
	if systemctl --user is-active ncalayer.service >/dev/null 2>&1; then
		printf 'NCALayer is already running as a systemd user service.\n' >&2
		printf 'Use "ncalayer --restart" to restart or "systemctl --user status ncalayer" to inspect.\n' >&2
		exit 0
	fi
	if pgrep -f -- "-jar ${JAR}" >/dev/null 2>&1; then
		printf 'warning: another instance of NCALayer appears to be running.\n' >&2
		printf 'warning: run "ncalayer --restart" if previous instance was unresponsive.\n' >&2
	fi
}

restart() {
	maybe_install_certs
	if systemctl --user restart ncalayer.service 2>/dev/null; then
		exit 0
	fi
	pkill -f -- "-jar ${JAR}" 2>/dev/null || true
	sleep 1
	exec "$JRE/bin/java" \
		-Djdk.gtk.version=3 \
		-Dsun.security.smartcardio.library="$PCSC_LIB" \
		-jar "$JAR" "$@"
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

check_running
maybe_install_certs
exec "$JRE/bin/java" \
	-Djdk.gtk.version=3 \
	-Dsun.security.smartcardio.library="$PCSC_LIB" \
	-jar "$JAR" "$@"
