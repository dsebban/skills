#!/usr/bin/env bash
# Runs on the pod, read-only: sp.sh ssh <id> 'bash -s' < this
# Per-request timings from Strata's /metrics, slot contents, cancels and warnings since the last start,
# expert placement, VRAM, and Tailscale Funnel proxy errors.
export PATH=/root/.local/bin:$PATH
K="$(tr '\0' '\n' < /proc/1/environ | sed -n 's/^STRATA_API_KEY=//p')"
echo "pod time $(date -u +%T) UTC"
curl -s -H "Authorization: Bearer $K" http://127.0.0.1:8080/metrics | python3 -c '
import sys, json, time
d = json.load(sys.stdin)
for r in sorted(d["requests"], key=lambda r: r["time"]):
    print(time.strftime("%H:%M:%S", time.gmtime(r["time"])), r["finish"], "prompt", r["prompt_tokens"],
          "reused", r.get("reused") or 0, "ttft_s", r.get("first_engine_token_s"), "out", r["output_tokens"],
          "decode_tok_s", r.get("decode_tok_s"), "total_s", r["duration_s"])
print("slots", [(s["slot"], s["state"], s.get("held_tokens")) for s in d["live"]["slots"]])'
L=$(ls -t /root/.local/state/strata/runtime/*.server.log | head -1)
n=$(grep -n "^ready:" "$L" | tail -1 | cut -d: -f1)
echo "finishes since last start:"; tail -n +"${n:-1}" "$L" | grep -oE "\((stop|length|cancel|error)[^)]*\)" | sort | uniq -c
echo "warnings and cancels (with the prompt size before each):"
tail -n +"${n:-1}" "$L" | grep -B1 -iE "warn|error|fail|cancel=True|side request" | cut -c1-160 | tail -20
grep -hE "experts=" $(ls -t /root/.local/state/strata/launch/*.engine.log | head -1) | tail -1 | grep -oE "experts=[^(]*"
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader
[ -f /root/tailscaled.log ] && echo "funnel proxy errors: $(grep -c 'proxy error' /root/tailscaled.log)"
