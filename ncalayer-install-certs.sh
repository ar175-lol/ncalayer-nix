#!/usr/bin/env bash
set -euo pipefail

certutil="@CERTUTIL@"
certs="@CERTS@"

add_certs() {
	local db="$1"
	"$certutil" -A -n "root_rsa.cer" -t "TCu,Cu," \
		-i "$certs/root_rsa.cer" -d "sql:$db" </dev/null >/dev/null 2>&1 || true
	"$certutil" -A -n "nca_rsa.cer" -t "TCu,Cu," \
		-i "$certs/nca_rsa.cer" -d "sql:$db" </dev/null >/dev/null 2>&1 || true
}

for db in "$HOME/.pki/nssdb" "$HOME/.local/share/pki/nssdb"; do
	if [ ! -d "$db" ]; then
		mkdir -p "$db"
		chmod 700 "$db"
		"$certutil" -N --empty-password -d "sql:$db" </dev/null >/dev/null 2>&1 || true
	fi
	add_certs "$db"
done

for profile in "$HOME"/.mozilla/firefox/* "$HOME"/.thunderbird/*; do
	[ -f "$profile/cert9.db" ] || continue
	add_certs "$profile"
done
