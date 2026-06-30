echo "=== 02: safety guard ==="

P="$SANDBOX/02-no-profile-no-export"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = { fnox_bin = "$FNOX_BIN" }
TOML
trust_project "$P"
expect_success "02.1 no profile/export succeeds without dumping default catalog" "$P"
check "02.2 no profile/export: ALPHA_TOKEN absent" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/02-unsafe-default-all"
setup_project "$P" "$DEFAULT_FNOX"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  unsafe_default_all = true,
}
TOML
trust_project "$P"
check "02.3 unsafe_default_all exports default catalog" "$([[ "$(getval "$P" DEFAULT_TOKEN)" == "default-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/02-config-path"
setup_project "$P"
cat > "$P/custom-fnox.toml" <<TOML
[secrets]
CONFIG_TOKEN = { default = "config-value" }
TOML
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  config = "$P/custom-fnox.toml",
  export = ["CONFIG_TOKEN"],
}
TOML
trust_project "$P"
check "02.4 explicit config path exports configured key" "$([[ "$(getval "$P" CONFIG_TOKEN)" == "config-value" ]] && echo 1 || echo 0)"
