#!/usr/bin/env bash
# Runs on the pod: sp.sh ssh <id> 'bash -s -- [strata launch args]' < this
# Fully stops Strata (a plain --restart with unchanged settings keeps the old server process), then starts it on the
# newest downloaded GGUF with the key from the container's STRATA_API_KEY. Default args are for Inkling on an A100 40 GB:
#   --family inkling-2-mini --context 128k --parallel 2 --set vram-experts-gb=16 --vision off --tune skip
# Drops in-flight requests: get the user's approval while they are using the model.
set -uo pipefail
export PATH=/root/.local/bin:$PATH
F=$(ls -t /root/strata-data/models/*/*.gguf | head -1)
ARGS=${*:---family inkling-2-mini --context 128k --parallel 2 --set vram-experts-gb=16 --vision off --tune skip}
export STRATA_API_KEY="$(tr '\0' '\n' < /proc/1/environ | sed -n 's/^STRATA_API_KEY=//p')"
[ -n "$STRATA_API_KEY" ] || { echo "STRATA_API_KEY is not in the container environment" >&2; exit 2; }
strata launch --stop >/dev/null 2>&1; sleep 5
nohup strata launch --model-path "$F" $ARGS --access lan --port 8080 --api-key-env STRATA_API_KEY \
  --data-dir /root/strata-data --yes --no-tui > /root/launch.log 2>&1 < /dev/null &
for i in $(seq 1 40); do sleep 5; curl -s -m 3 http://127.0.0.1:8080/health | grep -q '"loaded": true' && break; done
curl -s -m 3 http://127.0.0.1:8080/health; echo
grep -E "experts=|prefill chunk" /root/.local/state/strata/launch/*.engine.log | tail -2 | cut -c1-200
