echo "=== 04: selectors ==="

P="$SANDBOX/04-exact"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
check "04.1 exact selector exports key" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"
check "04.2 exact selector filters other keys" "$([[ "$(has_key "$P" BETA_TOKEN)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/04-star"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = ["*"],
}
TOML
trust_project "$P"
check "04.3 star selector exports ALPHA_TOKEN" "$(has_key "$P" ALPHA_TOKEN)"
check "04.4 star selector exports BETA_TOKEN" "$(has_key "$P" BETA_TOKEN)"

P="$SANDBOX/04-prefix-glob"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = ["SERVICE_*"],
}
TOML
trust_project "$P"
check "04.5 prefix glob exports SERVICE_FOO" "$(has_key "$P" SERVICE_FOO)"
check "04.6 prefix glob exports SERVICE_BAR" "$(has_key "$P" SERVICE_BAR)"
check "04.7 prefix glob filters ALPHA_TOKEN" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/04-missing-silent"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = ["DOES_NOT_EXIST"],
}
TOML
trust_project "$P"
expect_success "04.8 missing selector is silent by default" "$P"
expect_no_warn "04.9 missing selector default emits no warning" "$P" "DOES_NOT_EXIST"

P="$SANDBOX/04-missing-warn"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  on_missing = "warn",
  export = ["DOES_NOT_EXIST"],
}
TOML
trust_project "$P"
expect_warn "04.10 missing selector warns when configured" "$P" "DOES_NOT_EXIST"

P="$SANDBOX/04-missing-error"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  on_missing = "error",
  export = ["DOES_NOT_EXIST"],
}
TOML
trust_project "$P"
expect_fail "04.11 missing selector errors when configured" "$P"

P="$SANDBOX/04-star-empty"
setup_project "$P" "$EMPTY_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["empty"],
  on_missing = "error",
  export = ["*"],
}
TOML
trust_project "$P"
expect_success "04.12 star succeeds even on empty profile" "$P"
