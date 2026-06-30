echo "=== 03: syntax ==="

P="$SANDBOX/03-multiline"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    "ALPHA_TOKEN",
    { from = "BETA_TOKEN" },
    { from = "GAMMA_RAW", to = "RENAMED_GAMMA" },
  ],
}
TOML
trust_project "$P"
check "03.1 string shorthand exports ALPHA_TOKEN" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"
check "03.2 table selector exports BETA_TOKEN" "$([[ "$(getval "$P" BETA_TOKEN)" == "beta-value" ]] && echo 1 || echo 0)"
check "03.3 mapping exports target" "$([[ "$(getval "$P" RENAMED_GAMMA)" == "gamma-value" ]] && echo 1 || echo 0)"
check "03.4 mapping drops source by default" "$([[ "$(has_key "$P" GAMMA_RAW)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/03-repeated-env"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[[env]]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}

[[env]]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = ["BETA_TOKEN"],
}
TOML
trust_project "$P"
check "03.5 repeated [[env]] exports first block" "$(has_key "$P" ALPHA_TOKEN)"
check "03.6 repeated [[env]] exports second block" "$(has_key "$P" BETA_TOKEN)"

P="$SANDBOX/03-old-grammar-rejected"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { OLD_TARGET = "ALPHA_TOKEN" },
  ],
}
TOML
trust_project "$P"
expect_fail "03.7 old target-as-key grammar rejected" "$P"

P="$SANDBOX/03-rename-property-rejected"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    { from = "ALPHA_TOKEN", rename = "OLD_NAME" },
  ],
}
TOML
trust_project "$P"
expect_fail "03.8 old rename property rejected" "$P"
