#!/usr/bin/env bash
# Integrator (sim stream): merges one commit or branch into main, in the
# integration worktree only (../FTGG-integration, a worktree on main; set
# FTGG_INTEGRATION to use another path). Never run merges in a working
# checkout.
#
#   bash tools/integration/integrate.sh <commit-or-branch> "<description>"
#
# Merges --no-ff, runs the fast suite (`lune run test`), the slow suite
# (`lune run test_slow`: AI matches, fairness) and `lune run build` there,
# and pushes main only if all pass. The client suite (`lune run test_client`,
# when present) runs too and is reported, not required: a new sim def fails
# it until the client stream draws its icon, so its failures go to the
# client stream instead of blocking the merge. The lobby stream's own suite
# (`lune run src/lobby/tools/test`, when present; it exits 1 on a failure)
# runs too and is required, like the fast suite (S-145, lobby stream's
# request). A conflict aborts the merge (exit 3); failed checks
# drop the local, unpushed merge (main back to origin/main, exit 4); a failed
# push keeps the checked merge for a retry (exit 5). Nothing
# is ever force-pushed. Record failures under "Integration notes" in the
# stream's progress file.
set -u
REF="$1"
DESC="$2"
HERE=$(cd "$(dirname "$0")/../.." && pwd)
WT="${FTGG_INTEGRATION:-$(cd "$HERE/.." && pwd)/FTGG-integration}"
cd "$WT" || { echo "no integration worktree at $WT (git worktree add ../FTGG-integration main)"; exit 2; }
[ "$(git branch --show-current)" = "main" ] || { echo "the integration worktree is not on main"; exit 2; }
git diff --quiet && git diff --cached --quiet || { echo "the integration worktree has local changes"; exit 2; }
git fetch -q origin
git merge -q --ff-only origin/main || { echo "local main diverged from origin/main"; exit 2; }
if ! git merge --no-ff "$REF" -m "Merge $DESC

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" > /tmp/ftgg-merge.log 2>&1; then
	echo "MERGE FAILED: $(tail -3 /tmp/ftgg-merge.log)"
	git merge --abort 2>/dev/null
	exit 3
fi
lune run test > /tmp/ftgg-test.log 2>&1
T=$(tail -1 /tmp/ftgg-test.log)
echo "test: $T"
grep -A2 "^  FAIL" /tmp/ftgg-test.log | head -20
S="0 failed (no slow suite)"
if [ -f .lune/test_slow.luau ]; then
	lune run test_slow > /tmp/ftgg-test_slow.log 2>&1
	S=$(tail -1 /tmp/ftgg-test_slow.log)
	grep -A2 "^  FAIL" /tmp/ftgg-test_slow.log | head -20
fi
echo "test_slow: $S"
C="0 failed (no client suite)"
if [ -f .lune/test_client.luau ]; then
	C=$(lune run test_client 2>&1 | tail -1)
fi
echo "test_client: $C"
echo "$C" | grep -q " 0 failed" || echo "CLIENT SUITE FAILURES (reported, not blocking): tell the client stream"
L="passed (no lobby suite)"
LOK=0
if [ -f src/lobby/tools/test.luau ]; then
	L=$(lune run src/lobby/tools/test 2>&1)
	LOK=$?
	L=$(echo "$L" | tail -1)
fi
echo "test_lobby: $L"
B=$(lune run build 2>&1 | tail -1)
echo "build: $B"
if echo "$T" | grep -q " 0 failed" && echo "$S" | grep -q " 0 failed" && [ $LOK -eq 0 ] && echo "$B" | grep -q "requires all resolve"; then
	if git push -q origin main; then
		echo "PUSHED $(git log --oneline -1)"
		exit 0
	fi
	# checks passed but the push didn't (network): the merge stays on the
	# worktree's main, ahead of origin; retry with `git push` there
	echo "PUSH FAILED: the checked merge is kept on the worktree's main; run git push there"
	exit 5
fi
echo "CHECKS FAILED: dropping the unpushed merge (main back to origin/main)"
git reset -q --hard origin/main
exit 4
