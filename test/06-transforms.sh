echo "=== 06: transforms ==="

P="$SANDBOX/06-strip-prefix"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "SERVICE_*", strip_prefix = "SERVICE_" },
  ],
}
TOML
trust_project "$P"
check "06.1 strip_prefix exports FOO" "$([[ "$(getval "$P" FOO)" == "service-foo" ]] && echo 1 || echo 0)"
check "06.2 strip_prefix exports BAR" "$([[ "$(getval "$P" BAR)" == "service-bar" ]] && echo 1 || echo 0)"
check "06.3 strip_prefix drops source" "$([[ "$(has_key "$P" SERVICE_FOO)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/06-replace-prefix"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "SERVICE_*", replace_prefix = ["SERVICE_", "APP_"] },
  ],
}
TOML
trust_project "$P"
check "06.4 replace_prefix exports APP_FOO" "$([[ "$(getval "$P" APP_FOO)" == "service-foo" ]] && echo 1 || echo 0)"
check "06.5 replace_prefix exports APP_BAR" "$([[ "$(getval "$P" APP_BAR)" == "service-bar" ]] && echo 1 || echo 0)"

P="$SANDBOX/06-prefix"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "ALPHA_*", prefix = "PREFIXED_" },
  ],
}
TOML
trust_project "$P"
check "06.6 prefix exports PREFIXED_ALPHA_TOKEN" "$([[ "$(getval "$P" PREFIXED_ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/06-combined"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "SERVICE_*", strip_prefix = "SERVICE_", prefix = "APP_" },
  ],
}
TOML
trust_project "$P"
check "06.7 combined transform exports APP_FOO" "$([[ "$(getval "$P" APP_FOO)" == "service-foo" ]] && echo 1 || echo 0)"

P="$SANDBOX/06-to-plus-transform"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "SERVICE_*", to = "BAD", strip_prefix = "SERVICE_" },
  ],
}
TOML
trust_project "$P"
expect_fail "06.8 to mixed with transform rejected" "$P"

P="$SANDBOX/06-invalid-result"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "ALPHA_TOKEN", replace_prefix = ["ALPHA_TOKEN", "lowercase"] },
  ],
}
TOML
trust_project "$P"
expect_fail "06.9 transform invalid env name rejected" "$P"

P="$SANDBOX/06-missing-warn"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "DEBUG_*", prefix = "APP_", on_missing = "warn" },
  ],
}
TOML
trust_project "$P"
expect_warn "06.10 transform no-match warns per entry" "$P" "DEBUG_"

P="$SANDBOX/06-missing-error"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "DEBUG_*", prefix = "APP_", on_missing = "error" },
  ],
}
TOML
trust_project "$P"
expect_fail "06.11 transform no-match errors per entry" "$P"
