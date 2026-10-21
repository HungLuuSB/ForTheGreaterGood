#!/usr/bin/env bash
# Integrator (sim stream): lists "Ready to merge: <commit>" entries in
# docs/progress/*.md on every local branch that main doesn't contain yet,
# then the client stream's requests for the sim session. Read-only.
#
#   bash tools/integration/check.sh
cd "$(dirname "$0")/../.." || exit 2
git fetch -q origin
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
	for f in $(git ls-tree --name-only "$b" docs/progress/ 2>/dev/null); do
		git show "$b:$f" | grep -o "Ready to merge: \`[0-9a-f]*\`" | grep -o "[0-9a-f]\{7,\}" | while read -r c; do
			git merge-base --is-ancestor "$c" main 2>/dev/null || echo "PENDING $b $f $c $(git log -1 --format=%s "$c")"
		done
	done
done
echo "--- requests (m-client-foundation):"
git show m-client-foundation:docs/progress/client.md | sed -n '/^## Requests for the sim session/,/^## /p' | sed '1d;$d'
