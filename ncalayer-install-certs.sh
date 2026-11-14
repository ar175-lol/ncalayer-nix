#!/usr/bin/env bash
set -euo pipefail

certutil="@CERTUTIL@"
find="@FIND@"
grep="@GREP@"
certs="@CERTS@"

found_db=0
failed=0

add_certs() {
	local db="$1" name
	found_db=1
	for name in root_rsa.cer nca_rsa.cer; do
		if "$certutil" -L -d "sql:$db" -n "$name" </dev/null 2>/dev/null |
			"$grep" -q 'Trusted CA'; then
			continue
		fi
		if ! "$certutil" -A -n "$name" -t "TCu,Cu," \
			-i "$certs/$name" -d "sql:$db" </dev/null >/dev/null 2>&1; then
			if ! "$certutil" -L -d "sql:$db" -n "$name" </dev/null >/dev/null 2>&1; then
				printf 'warning: could not install %s into %s\n' "$name" "$db" >&2
				printf 'warning: close the browser and run ncalayer-install-certs again\n' >&2
				failed=1
				continue
			fi
		fi
		# `-A` leaves existing (untrusted) entries untouched; force the trust
		# flags so browsers actually accept NCALayer's local HTTPS certificate.
		if ! "$certutil" -M -n "$name" -t "TCu,Cu," \
			-d "sql:$db" </dev/null >/dev/null 2>&1; then
			printf 'warning: could not trust %s in %s\n' "$name" "$db" >&2
			printf 'warning: close the browser and run ncalayer-install-certs again\n' >&2
			failed=1
		fi
	done
}

create_db() {
	local db="$1"
	mkdir -p "$db"
	chmod 700 "$db"
	"$certutil" -N --empty-password -d "sql:$db" </dev/null >/dev/null 2>&1 || true
}

for cert in root_rsa.cer nca_rsa.cer; do
	if [ ! -s "$certs/$cert" ]; then
		printf 'warning: missing certificate %s\n' "$certs/$cert" >&2
		failed=1
	fi
done

if [ "$failed" -eq 1 ]; then
	printf 'warning: NCALayer certificates are incomplete; browsers will reject the local HTTPS API\n' >&2
	exit 0
fi

# Chromium / Chrome.
for db in "$HOME/.pki/nssdb" "$HOME/.local/share/pki/nssdb"; do
	[ -d "$db" ] || continue
	add_certs "$db"
done

# Firefox and its forks each keep their own NSS databases. Missing a fork (for
# example LibreWolf) is the usual reason why NCALayer's HTTPS server is
# unreachable even though Chromium works.
for base in \
	"$HOME/.mozilla/firefox" \
	"$HOME/.mozilla/seamonkey" \
	"$HOME/.thunderbird" \
	"$HOME/.betterbird" \
	"$HOME/.librewolf" \
	"$HOME/.waterfox" \
	"$HOME/.floorp" \
	"$HOME/.zen" \
	"$HOME/.basilisk" \
	"$HOME/.palemoon" \
	"$HOME/.config/mozilla/firefox" \
	"$HOME/.config/thunderbird" \
	"$HOME/.config/betterbird" \
	"$HOME/.config/librewolf" \
	"$HOME/.config/waterfox" \
	"$HOME/.config/floorp" \
	"$HOME/.config/zen" \
	"$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
	"$HOME/.var/app/io.gitlab.librewolf-community/.librewolf" \
	"$HOME/.var/app/org.mozilla.Thunderbird/.thunderbird" \
	"$HOME/.var/app/app.zen_browser.zen/.zen" \
	"$HOME/.var/app/app.zen_browser.zen/.config/zen"; do
	[ -d "$base" ] || continue
	while IFS= read -r -d '' certdb; do
		add_certs "$(dirname "$certdb")"
	done < <("$find" "$base" -maxdepth 3 -name cert9.db -print0 2>/dev/null)
done

if [ "$found_db" -eq 0 ]; then
	# No browser has created its certificate database yet. Chromium/Chrome use
	# ~/.pki/nssdb on Linux, so create it now and they will pick it up on first
	# start. Firefox-family browsers still need this script to run again after
	# they create a profile (the systemd timer and launcher do that).
	create_db "$HOME/.pki/nssdb"
	add_certs "$HOME/.pki/nssdb"
	printf 'warning: no existing browser certificate database found\n' >&2
	printf 'warning: created %s\n' "$HOME/.pki/nssdb" >&2
	printf 'warning: Firefox/LibreWolf/Zen profiles are handled after their first start\n' >&2
fi

if [ "$failed" -eq 1 ]; then
	printf 'warning: some NCALayer certificates could not be installed\n' >&2
	exit 1
fi

exit 0
