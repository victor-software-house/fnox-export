echo "=== 05: mappings ==="

P="$SANDBOX/05-mapping"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "ALPHA_TOKEN", to = "MAPPED_TOKEN" },
  ],
}
TOML
trust_project "$P"
check "05.1 mapping exports target" "$([[ "$(getval "$P" MAPPED_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"
check "05.2 mapping drops source" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/05-source-from"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "FROM", to = "OUTPUT_KEY" },
  ],
}
TOML
trust_project "$P"
check "05.3 source key named FROM works" "$([[ "$(getval "$P" OUTPUT_KEY)" == "from-upper" ]] && echo 1 || echo 0)"

P="$SANDBOX/05-lowercase-mapping"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "ALPHA_TOKEN", to = "lowercase_target" },
  ],
}
TOML
trust_project "$P"
expect_fail "05.4 lowercase to target rejected" "$P"

P="$SANDBOX/05-missing-mapping-silent"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "DOES_NOT_EXIST", to = "MISSING_TARGET" },
    "BETA_TOKEN",
  ],
}
TOML
trust_project "$P"
expect_success "05.5 missing mapping source silent by default" "$P"
check "05.6 missing mapping source does not skip other entries" "$([[ "$(getval "$P" BETA_TOKEN)" == "beta-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/05-missing-mapping-warn"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "DOES_NOT_EXIST", to = "MISSING_TARGET", on_missing = "warn" },
  ],
}
TOML
trust_project "$P"
expect_warn "05.7 missing mapping source warns per entry" "$P" "DOES_NOT_EXIST"

P="$SANDBOX/05-missing-mapping-error"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "DOES_NOT_EXIST", to = "MISSING_TARGET", on_missing = "error" },
  ],
}
TOML
trust_project "$P"
expect_fail "05.8 missing mapping source errors per entry" "$P"
