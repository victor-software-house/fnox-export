#!/usr/bin/env bash
# Release = tag the current metadata.lua version and push the tag.
#
# Versions are patch-bumped per commit (see AGENTS.md), so this does NOT bump —
# it publishes a lightweight tag pointing at the already-committed version, which
# is what mise plugin consumers can pin to. Annotated tags are avoided on purpose:
# `mise plugin` fetch can fail on annotated tag objects.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

version="$(sed -n 's/^PLUGIN\.version = "\(.*\)"/\1/p' metadata.lua)"
if [ -z "$version" ]; then
	echo "release: could not read PLUGIN.version from metadata.lua" >&2
	exit 1
fi
tag="v$version"

# The tag must point at a committed, pushed state.
if [ -n "$(git status --porcelain)" ]; then
	echo "release: working tree is dirty — commit the version bump first" >&2
	exit 1
fi

# HEAD must already be on the upstream branch, or the tag would publish an
# unpushed commit. Compare HEAD against its tracking ref.
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -z "$upstream" ]; then
	echo "release: no upstream tracking branch — push the branch first" >&2
	exit 1
fi
if [ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]; then
	echo "release: HEAD differs from $upstream — push commits before tagging" >&2
	exit 1
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
	echo "release: tag $tag already exists (bump PLUGIN.version for a new release)" >&2
	exit 1
fi

# Lightweight tag only (no -a / -m).
git tag "$tag"
git push origin "$tag"
echo "released $tag"
