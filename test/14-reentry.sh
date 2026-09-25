echo "=== 14: re-entry guard ==="

# A mise shim is a symlink to the mise binary named after the tool. When one
# named `fnox` precedes the real fnox on PATH, every fnox call the plugin makes
# is mise again: it evaluates the env, runs this plugin, and calls fnox again.
# Without a guard that recursion is unbounded, so the probe runs in its own
# process group under a per-user process cap and a hard timeout that kills
# the whole group.
P="$SANDBOX/14-reentry"
setup_project "$P"
mkdir -p "$P/shim"
ln -s "$(command -v mise)" "$P/shim/fnox"
cat > "$P/mise.toml" <<TOML
[env]
_.fnox-export = {
  profiles = ["demo"],
  export = ["ALPHA_TOKEN"],
}
TOML
trust_project "$P"
out="$SANDBOX/14-reentry-out.$$"
cap=$(( $(ps -U "$(id -u)" -o pid= | wc -l) + 32 ))
if (
    ulimit -u "$cap"
    cd "$P" && PATH="$P/shim:$PATH" timeout -s KILL 20 mise env -s bash
) >"$out" 2>/dev/null && grep -q "^export ALPHA_TOKEN=" "$out"; then
    check "14.1 fnox resolving to a mise shim does not re-enter the plugin" 1
else
    check "14.1 fnox resolving to a mise shim does not re-enter the plugin" 0
fi
rm -f "$out"
