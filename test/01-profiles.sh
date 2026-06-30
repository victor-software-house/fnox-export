echo "=== 01: profiles ==="

P="$SANDBOX/01-profile-export-all"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profiles = ["demo"],
}
TOML
trust_project "$P"
check "01.1 profile export-all: ALPHA_TOKEN present" "$(has_key "$P" ALPHA_TOKEN)"
check "01.2 profile export-all: BETA_TOKEN present" "$(has_key "$P" BETA_TOKEN)"
check "01.3 profile export-all: GAMMA_RAW present" "$(has_key "$P" GAMMA_RAW)"

P="$SANDBOX/01-profile-alias"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profile = "demo",
}
TOML
trust_project "$P"
check "01.4 profile alias exports profile" "$(has_key "$P" ALPHA_TOKEN)"

P="$SANDBOX/01-profile-conflict"
setup_project "$P"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  fnox_bin = "$FNOX_BIN",
  profile = "demo",
  profiles = ["demo"],
}
TOML
trust_project "$P"
expect_fail "01.5 profile+profiles conflict errors" "$P"
