#!/usr/bin/env bash
# Runs on the pod (sp.sh ssh <id> 'bash -s' < this). Idempotent.
# Strata 0.2.21 sends a new conversation to a spare slot only when its prompt is under 2,048 tokens; longer ones take
# slot 0 and wipe the cached main chat. This makes any new conversation keep off the chat slot 0 holds.
# Restart Strata afterwards (pod-strata-launch.sh) so the patched server loads. Backup: server.py.orig
set -euo pipefail
P=$(ls -d /root/.local/share/strata/terminal/*/serve/server.py | tail -1)
cd "$(dirname "$P")"
if grep -q "local patch: any new conversation keeps off" server.py; then echo "already patched: $P"; exit 0; fi
[ -f server.py.orig ] || cp server.py server.py.orig
python3 - <<'EOF'
p = "server.py"; s = open(p).read()
old = "            if (not self.slot_busy[0] and len(self.slot_held[0]) >= self.SIDE_REQUEST_MIN and len(prompt) < self.SIDE_REQUEST_MIN):"
new = "            if (not self.slot_busy[0] and self.slot_held[0]):  # local patch: any new conversation keeps off the chat slot 0 holds"
n = s.count(old)
if n != 1:
    raise SystemExit(f"expected line found {n} times; this Strata version differs, read _inkling_route and adapt")
open(p, "w").write(s.replace(old, new)); print("patched", p)
EOF
rm -f __pycache__/server.cpython-*.pyc
