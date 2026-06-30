echo "=== 09: errors and warning levels ==="

P="$SANDBOX/09-entry-overrides-global"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  on_missing = "error",
  export = [
    { from = "DOES_NOT_EXIST", on_missing = "silent" },
    "ALPHA_TOKEN",
  ],
}
TOML
trust_project "$P"
expect_success "09.1 per-entry on_missing overrides global" "$P"
check "09.2 per-entry override does not skip other keys" "$([[ "$(getval "$P" ALPHA_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"

P="$SANDBOX/09-invalid-on-missing"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  on_missing = "loud",
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
expect_fail "09.3 invalid on_missing rejected" "$P"

P="$SANDBOX/09-invalid-on-failure"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  on_failure = "loud",
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
expect_fail "09.4 invalid on_failure rejected" "$P"

P="$SANDBOX/09-on-failure-default-warn"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "/nonexistent/fnox-binary",
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
expect_warn "09.5 on_failure default warns" "$P" "fnox export failed"
check "09.6 failed batch export returns no ALPHA_TOKEN" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"

P="$SANDBOX/09-on-failure-error"
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
expect_fail "09.7 on_failure=error hard fails" "$P"

P="$SANDBOX/09-on-failure-silent"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "/nonexistent/fnox-binary",
  profiles = ["demo"],
  on_failure = "silent",
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
expect_success "09.8 on_failure=silent succeeds" "$P"
expect_no_warn "09.9 on_failure=silent emits no warning" "$P" "fnox export failed"
