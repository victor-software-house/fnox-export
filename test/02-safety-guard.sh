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

P="$SANDBOX/02-config-root"
setup_project "$P"
mkdir -p "$P/nested/deeper"
cat > "$P/custom-fnox.toml" <<TOML
[secrets]
CONFIG_ROOT_TOKEN = { default = "config-root-value" }
TOML
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  config = "{{config_root}}/custom-fnox.toml",
  export = ["CONFIG_ROOT_TOKEN"],
}
TOML
trust_project "$P"
check "02.5 config_root path exports from nested cwd" "$([[ "$(getval "$P/nested/deeper" CONFIG_ROOT_TOKEN)" == "config-root-value" ]] && echo 1 || echo 0)"
