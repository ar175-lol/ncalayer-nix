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

if [ ! -d "$HOME/.pki/nssdb" ] && [ ! -d "$HOME/.local/share/pki/nssdb" ]; then
	mkdir -p "$HOME/.local/share/pki/nssdb"
	chmod 700 "$HOME/.local/share/pki/nssdb"
	"$certutil" -N --empty-password -d "sql:$HOME/.local/share/pki/nssdb" </dev/null >/dev/null 2>&1 || true
fi

for db in "$HOME/.pki/nssdb" "$HOME/.local/share/pki/nssdb"; do
	[ -d "$db" ] || continue
	add_certs "$db"
done

for profile in "$HOME"/.mozilla/firefox/* "$HOME"/.thunderbird/*; do
	[ -f "$profile/cert9.db" ] || continue
	add_certs "$profile"
done
