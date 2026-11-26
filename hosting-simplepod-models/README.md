# hosting-simplepod-models

An agent skill that puts an open-weight GGUF model on a rented [SimplePod](https://simplepod.ai) GPU and adds it to [Amp](https://ampcode.com) as a model you can pick for your threads. It rents the GPU, serves the model with [Strata](https://github.com/Niko1221/Strata) (or llama.cpp), puts it behind a publicly trusted HTTPS URL with [Tailscale Funnel](https://tailscale.com/kb/1223/funnel), adds the Amp Custom URL connection, checks health and speed, and stops the instance when you are done.

The worked example in `reference/inkling-2-mini-run.md` hosts [AtomicChat/Inkling-2-Mini-Uncensored-GGUF](https://huggingface.co/AtomicChat/Inkling-2-Mini-Uncensored-GGUF) and records every number and failure along the way.

## What you need

- A SimplePod account with balance, and an API key (Account Settings → Subaccounts), stored as the secret `SIMPLEPOD_API_TOKEN`.
- A Tailscale tailnet (the free plan works) with MagicDNS and HTTPS certificates on, a tag such as `tag:simplepod-model` with the `funnel` node attribute, and an API key stored as `TAILSCALE_API_KEY`. Amp calls custom models from its own servers, so the model needs a public HTTPS URL; plain `http://IP:port` is rejected.
- An endpoint key you choose (32+ random characters), stored as a secret such as `MODEL_API_KEY`. You also enter it in the Amp connection.
- Amp with Model Routing (Custom URL connections are available on every tier). `node`/`npx`, `curl`, `jq`, and `sshpass` (installed on demand) where the agent runs.

## Install

- **Amp:** `amp skill add --global dsebban/skills/hosting-simplepod-models`, or copy this directory into `.agents/skills/` of a project. Then ask, for example: "Use hosting-simplepod-models to host AtomicChat/Inkling-2-Mini-Uncensored-GGUF."
- **Claude Code:** copy this directory to `~/.claude/skills/hosting-simplepod-models/`. The SimplePod MCP server is declared in the SKILL.md frontmatter; if your client does not read `mcpServers` from skills, add it yourself: `npx -y @simplepod.ai/mcp-rental@0.1.1` with env `API_TOKEN=$SIMPLEPOD_API_TOKEN`.
- **Codex and other agents:** copy the directory into your agent's skills folder and add the same MCP server. The Amp-specific step (adding the Custom URL connection) still happens in Amp Settings → Model Routing.

The skill asks for your approval before it rents, deletes, recreates, or restarts anything.

## Rough costs

SimplePod prices from November 2026, per hour, plus about $0.017/h for an 80 GB disk:

- RTX 3090 24 GB: about $0.16. Fits a 16 GB model with one slot, but a MoE model may not fit all its experts (slower).
- A100 40 GB: about $0.42. What the Inkling example ended on: all experts on the GPU, two slots, ~$0.44/h total.

Billing runs until the instance is deleted; Docker instances cannot be paused.

## Benchmarks

Measured with Inkling-2-Mini-Uncensored (Q4_K GGUF, 16.5 GB) on Strata 0.2.21, through Tailscale Funnel, during real Amp use in November 2026. One model, one run, not a lab benchmark.

| | RTX 3090 24 GB | A100 40 GB |
|---|---|---|
| Price incl. 80 GB disk | $0.177/h | $0.437/h |
| Experts on the GPU | 2,563 of 3,072 (rest in host RAM) | 3,072 of 3,072 |
| Cold prompt reading | ~290 tok/s | ~300–310 tok/s |
| Writing (decode), short context | 54–72 tok/s | 67 tok/s |
| Writing at 48–60k context | – | 47–53 tok/s |
| Writing at 102k context | – | 41 tok/s |
| Two slots | stalled at 0 tok/s | works, with the router patch |

Cold prompt reads on the A100, by prompt size (time to first token):

| Prompt tokens | Time |
|---|---|
| 19,032 | 62 s |
| 49,375–51,383 | 160 s |
| 54,430 | 180 s |
| 57,361–57,444 | 190 s |
| 101,756 | over 300 s; Amp cancelled it twice |

Cached turns, where the server still holds the thread: time to first token 0.16 s at 19k tokens and 0.3–1.8 s at 55–60k tokens (median about 0.6 s). Without the router patch, one side request in between evicted the thread and the next turn took 61.7 s instead of 0.59 s.

Compaction: with Input Tokens 65536, Amp compacted a long thread at about 57–60k tokens. The compaction request took 250 s (191 s to read 57,444 tokens, then 2,999 summary tokens), and the first turn after it was another cold read of about 160 s.

Other: Tailscale Funnel added about 0.28 s per request. 257 of 260 requests in one working session finished normally. Strata's model card reports 4,000–11,000 tok/s prompt reading on RTX 50-series cards; that was not measured here.

## What was tested

Tested end to end on one model (Inkling-2-Mini-Uncensored, Strata 0.2.21):

- Picking a host, renting an RTX 3090 and then an A100, downloading and checksumming the GGUF, serving with Strata, the router patch, `vram-experts-gb`, Tailscale Funnel HTTPS (including moving the name to a new pod), the Amp Custom URL connection, real Amp threads (257 of 260 requests finished normally), the health report, and deleting an instance.
- `scripts/sp.sh` (summary, status, endpoint, ssh), `pod-patch-strata-router.sh`, and `pod-strata-report.sh` ran against the live instance as written.

- A final dry run of the published files on a fresh A100: `sp.sh create` from a template made from `simplepod-start-script.sh` (running in about 30 s, GGUF downloaded and checksum-verified in about 1 min), `pod-patch-strata-router.sh`, `pod-strata-launch.sh`, `mint-tailscale-key.sh`, `pod-funnel.sh` (same HTTPS name came back), and `pod-strata-report.sh`. Over HTTPS: a valid certificate, 401 without the key, `/v1/models`, a chat request, a tool call, SSE streaming ending in `[DONE]`, and a second turn reusing 19,034 of 19,049 prompt tokens from the cache after an unrelated request in between.

Not tested as packaged here:

- `sp.sh delete` in this form (instances were deleted during the run, but not with this script).
- The default Tailscale tag `tag:simplepod-model`: the dry run passed an existing tag through `TS_TAG`. Create the tag with the funnel attribute first, as the skill describes.
- Any model other than Inkling-2-Mini, and llama.cpp beyond the first attempt.
- The router patch matches Strata 0.2.21's `server.py` exactly; on another version the script stops and says so.

## Files

- `SKILL.md`: the workflow, approvals and secrets, health checks, stopping, and gotchas.
- `scripts/`: `sp.sh` (SimplePod API), `simplepod-start-script.sh` (template start script), `pod-patch-strata-router.sh`, `pod-strata-launch.sh`, `pod-strata-report.sh`, `mint-tailscale-key.sh`, `pod-funnel.sh`. Each prints usage at the top.
- `reference/inkling-2-mini-run.md`: the worked example.

Not affiliated with SimplePod, Tailscale, Strata, or Amp. The Inkling example model answers requests the original refuses; you are responsible for how you use it.
