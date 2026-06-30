echo "=== 10: mixed list ==="

P="$SANDBOX/10-mixed"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
  export = [
    "BETA_TOKEN",
    { from = "ALPHA_TOKEN", to = "SCM_TOKEN" },
    { from = "SERVICE_*", strip_prefix = "SERVICE_" },
    { from = "DOES_NOT_EXIST", on_missing = "silent" },
    "*",
  ],
}
TOML
trust_project "$P"
check "10.1 mixed list exports exact selector" "$([[ "$(getval "$P" BETA_TOKEN)" == "beta-value" ]] && echo 1 || echo 0)"
check "10.2 mixed list exports mapping" "$([[ "$(getval "$P" SCM_TOKEN)" == "alpha-value" ]] && echo 1 || echo 0)"
check "10.3 mixed list exports transform FOO" "$([[ "$(getval "$P" FOO)" == "service-foo" ]] && echo 1 || echo 0)"
check "10.4 mixed list drops mapped source from star" "$([[ "$(has_key "$P" ALPHA_TOKEN)" == "0" ]] && echo 1 || echo 0)"
check "10.5 mixed list drops transformed source from star" "$([[ "$(has_key "$P" SERVICE_FOO)" == "0" ]] && echo 1 || echo 0)"
check "10.6 mixed list keeps unrelated star key" "$([[ "$(getval "$P" GAMMA_RAW)" == "gamma-value" ]] && echo 1 || echo 0)"
