{
  lib,
  runCommand,
  unzip,
  coreutils,
  gnugrep,
  gnused,
  file,
  nssTools,
  ncalayer,
}:
runCommand "ncalayer-checks" {
  buildInputs = [unzip coreutils gnugrep gnused file nssTools];
} ''
  set -euo pipefail

  unzip -tq ${ncalayer}/lib/ncalayer/ncalayer.jar \
    | tail -n1 | grep -q 'No errors detected'

  ${ncalayer}/lib/ncalayer/jre8_ncalayer/bin/java -version 2>&1 \
    | grep -q '1.8.0'

  test "$(${ncalayer}/bin/ncalayer --version)" = "NCALayer 1.4"

  for f in \
    "${ncalayer}/bin/ncalayer" \
    "${ncalayer}/bin/ncalayer-install-certs" \
    "${ncalayer}/bin/showBundleManager" \
    "${ncalayer}/bin/showSettings" \
    "${ncalayer}/share/applications/ncalayer.desktop" \
    "${ncalayer}/share/icons/hicolor/512x512/apps/ncalayer.png" \
    "${ncalayer}/share/ncalayer/certs/root_rsa.cer" \
    "${ncalayer}/share/ncalayer/certs/nca_rsa.cer" \
    "${ncalayer}/lib/ncalayer/ncalayer.jar"
  do
    test -e "$f"
  done
  test -d "${ncalayer}/lib/ncalayer/jre8_ncalayer"

  grep -q '^Exec=ncalayer$' \
    "${ncalayer}"/share/applications/ncalayer.desktop

  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.local/share/pki/nssdb" "$HOME/.librewolf/default" "$HOME/.config/zen/default"
  ${nssTools}/bin/certutil -N --empty-password -d "sql:$HOME/.local/share/pki/nssdb"
  ${nssTools}/bin/certutil -N --empty-password -d "sql:$HOME/.librewolf/default"
  ${nssTools}/bin/certutil -N --empty-password -d "sql:$HOME/.config/zen/default"

  # Pre-seed one profile with untrusted certificates: the installer must fix
  # the trust flags, not merely notice that the entries already exist.
  for cert in root_rsa.cer nca_rsa.cer; do
    ${nssTools}/bin/certutil -A -n "$cert" -t ",," \
      -i "${ncalayer}/share/ncalayer/certs/$cert" \
      -d "sql:$HOME/.librewolf/default"
  done

  ${ncalayer}/bin/ncalayer-install-certs

  for db in \
    "$HOME/.local/share/pki/nssdb" \
    "$HOME/.librewolf/default" \
    "$HOME/.config/zen/default"
  do
    for cert in root_rsa.cer nca_rsa.cer; do
      ${nssTools}/bin/certutil -L -d "sql:$db" | grep -qE "^$cert +CT,C,"
    done
  done

  # Fresh install: no browser has created a profile yet. The installer must
  # create Chromium's database so the first browser start already trusts the
  # NCALayer HTTPS certificate.
  fresh_home=$(mktemp -d)
  HOME="$fresh_home" ${ncalayer}/bin/ncalayer-install-certs 2>/dev/null
  for cert in root_rsa.cer nca_rsa.cer; do
    ${nssTools}/bin/certutil -L -d "sql:$fresh_home/.pki/nssdb" \
      | grep -qE "^$cert +CT,C,"
  done

  # The launcher must refresh browser trust stores itself, so `nix run
  # .#ncalayer` also works when no module timer is active.
  grep -q 'ncalayer-install-certs' "${ncalayer}/bin/ncalayer"

  out_file=$(mktemp)
  ${ncalayer}/bin/ncalayer >"$out_file" 2>&1 &
  launcher_pid=$!
  sleep 5
  if kill -0 "$launcher_pid" 2>/dev/null; then
    : ok
  else
    wait "$launcher_pid" || true
    if grep -qEi 'invalid or corrupt jarfile|unsupportedclassversion|no class load' "$out_file"; then
      cat "$out_file"
      exit 1
    fi
    : ok
  fi
  kill "$launcher_pid" 2>/dev/null || true
  wait "$launcher_pid" 2>/dev/null || true

  echo "ncalayer: all checks passed"
  mkdir -p "$out"
  echo "ok" > "$out"/result
''
