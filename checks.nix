{
  lib,
  runCommand,
  unzip,
  coreutils,
  gnugrep,
  gnused,
  file,
  ncalayer,
}:
runCommand "ncalayer-checks" {
  buildInputs = [unzip coreutils gnugrep gnused file];
} ''
  set -euo pipefail

  unzip -tq ${ncalayer}/lib/ncalayer/ncalayer.jar \
    | tail -n1 | grep -q 'No errors detected'

  ${ncalayer}/lib/ncalayer/jre8_ncalayer/bin/java -version 2>&1 \
    | grep -q '1.8.0'

  test "$(${ncalayer}/bin/ncalayer --version)" = "NCALayer 1.4"

  for f in \
    "${ncalayer}/bin/ncalayer" \
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
