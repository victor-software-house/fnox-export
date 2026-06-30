echo "=== 12: environment controls ==="

P="$SANDBOX/12-disable"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "/nonexistent/fnox-binary",
  profiles = ["demo"],
  on_failure = "error",
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
if ( cd "$P" && FNOX_EXPORT_DISABLE=1 mise env -s bash ) >/dev/null 2>&1; then
    check "12.1 FNOX_EXPORT_DISABLE succeeds without fnox" 1
else
    check "12.1 FNOX_EXPORT_DISABLE succeeds without fnox" 0
fi
if ( cd "$P" && FNOX_EXPORT_DISABLE=1 mise env -s bash ) 2>/dev/null | grep -q "^export ALPHA_TOKEN="; then
    check "12.2 FNOX_EXPORT_DISABLE returns empty env" 0
else
    check "12.2 FNOX_EXPORT_DISABLE returns empty env" 1
fi

P="$SANDBOX/12-on-failure-silent-env"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "/nonexistent/fnox-binary",
  profiles = ["demo"],
  on_failure = "warn",
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
out="$SANDBOX/12-on-failure-out.$$"
err="$SANDBOX/12-on-failure-err.$$"
if ( cd "$P" && FNOX_EXPORT_ON_FAILURE=silent mise env -s bash ) >"$out" 2>"$err" && ! grep -q "fnox export failed" "$err"; then
    check "12.3 FNOX_EXPORT_ON_FAILURE=silent overrides option" 1
else
    check "12.3 FNOX_EXPORT_ON_FAILURE=silent overrides option" 0
fi
rm -f "$out" "$err"

P="$SANDBOX/12-on-missing-error-env"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  on_missing = "silent",
  export = ["DOES_NOT_EXIST"],
}
TOML
trust_project "$P"
if ( cd "$P" && FNOX_EXPORT_ON_MISSING=error mise env -s bash ) >/dev/null 2>&1; then
    check "12.4 FNOX_EXPORT_ON_MISSING=error overrides option" 0
else
    check "12.4 FNOX_EXPORT_ON_MISSING=error overrides option" 1
fi
