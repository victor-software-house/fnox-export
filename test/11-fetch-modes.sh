echo "=== 11: batch fetch ==="

P="$SANDBOX/11-batch-default"
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
check "11.1 batch default exports exact key" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/11-fetch-option-rejected"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  fetch = "individual",
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
expect_fail "11.2 removed fetch option is rejected" "$P"
