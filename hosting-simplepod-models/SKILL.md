---
name: hosting-simplepod-models
description: "Rents a SimplePod GPU, serves an open-weight GGUF model on it with Strata (or llama.cpp), exposes it over trusted HTTPS with Tailscale Funnel, and adds it to Amp as a Custom URL model the user can pick. Also checks its health and speed and stops it. Use when asked to run, host, set up, speed up, check, or stop a SimplePod model in Amp, or about SimplePod GPUs, rentals, balance, or instances. Not for Amp's built-in models or for models running on the user's own machine."
mcpServers:
  simplepod:
    command: npx
    args: ["-y", "@simplepod.ai/mcp-rental@0.1.1"]
    env:
      API_TOKEN: "${SIMPLEPOD_API_TOKEN}"
    includeTools: ["sp_get_summary", "sp_list_docker_market", "sp_list_instances", "sp_get_instance", "sp_list_templates", "sp_create_template", "sp_list_global_templates", "sp_get_global_template", "sp_reboot_instances", "sp_delete_instance", "sp_list_billing"]
---

# Hosting SimplePod models in Amp

The end state is: one SimplePod Docker GPU instance serves the model with an API key, `https://<hostname>.<tailnet>.ts.net/v1` reaches it over a publicly trusted certificate, an Amp Custom URL connection maps a model ID to it, and a real Amp thread on that model completes a prompt. Report the GPU, its hourly price (GPU plus disk), and how to stop it.

`reference/inkling-2-mini-run.md` is a worked example (Inkling-2-Mini-Uncensored, November 2026) with every number and failure. Read it when hosting an Inkling model or when a step below fails.

## Approvals and secrets

- Renting, deleting, or recreating an instance spends the user's SimplePod balance or takes the model offline. Get the user's approval of the exact action and configuration first. Restarting the model server while the user is using it also needs approval.
- Refer to secrets by name only; never put values in chat, files, or echoed command lines:
  - `SIMPLEPOD_API_TOKEN`: SimplePod API key (Account Settings → Subaccounts). Sent as header `X-AUTH-TOKEN` to `https://api.simplepod.ai`. If the MCP tools return "Unauthorized — check your API_TOKEN", ask the user to add it as an Amp secret.
  - `TAILSCALE_API_KEY`: Tailscale API key, used only to mint short-lived device keys.
  - The endpoint key, for example `MODEL_API_KEY`: create it with `manage_amp` topic `secrets` operation `set` without `generated_value`, so the user types it in a masked dialog. Ask for at least 32 random characters. The user enters the same value in the Custom URL connection's API key field.
- `sp_get_template` and `GET /instances/templates/{id}` return env var values in clear text. Never read a template that stores a key; pass keys as instance env vars at creation instead. `sp_create_docker_instance` and `sp_update_instance` are left out of this skill for the same reason: their arguments land in the transcript. Use `scripts/sp.sh create`, which reads the key from the environment.

## Workflow

1. **Size the model.** Read the Hugging Face model card: file sizes, architecture, required llama.cpp or Strata version, and whether it is a mixture of experts (MoE). Get the exact byte size and sha256 from `https://huggingface.co/api/models/<repo>/tree/main` (`size`, `lfs.oid`).
2. **Pick the GPU.** `sp_list_docker_market` with `rentalStatus: "active"` and `orderPricePerGpu: "asc"`. Choose the cheapest single-GPU host where the whole model fits in VRAM with at least 8 GB left for KV cache and a second slot, driver 580 or newer, and CUDA 13. For a MoE model, "fits" means every expert resident: on a 24 GB RTX 3090 the 16.5 GB Inkling Q4 left 509 of 3,072 experts in host RAM, which ran them on a busy shared CPU and stalled two slots; an A100 40 GB held them all. Skip V100 (no CUDA 13 engine). Check `scripts/sp.sh summary` for the balance; report hours left at the full price including disk.
3. **Template.** Create a private template with `sp_create_template`: `startScript` = the contents of `scripts/simplepod-start-script.sh`, image `nvidia/cuda`, tag `12.8.1-cudnn-devel-ubuntu22.04`, disk 80, ports `8080,22`, SSH on. Never edit a template while an instance made from it runs: SimplePod recreates the instance and wipes its disk. `PUT /instances/{id}` with new env vars can recreate it too. Make a new template instead.
4. **Rent.** After approval: `scripts/sp.sh create <market-id> <template-id> MODEL_API_KEY MODEL_URL=<gguf url> [STRATA_ARGS="..."]`. Poll `scripts/sp.sh status <id>` until `running`. Port 8080 maps to `ports.direct[].destPort` on the host IP; `scripts/sp.sh ssh <id>` logs in as root (the password is the instance `hashId`).
5. **Serve.** The start script downloads the GGUF with 16-connection `aria2c` (a single `curl` stalled at 1 MB/s), installs Strata 0.2.21, and launches it. Then:
   - Confirm the sha256 against Hugging Face: `scripts/sp.sh ssh <id> sha256sum <path>` (takes a few minutes; run it in the background).
   - Apply the router patch: `scripts/sp.sh ssh <id> 'bash -s' < scripts/pod-patch-strata-router.sh`, then restart Strata with `scripts/sp.sh ssh <id> 'bash -s' < scripts/pod-strata-launch.sh` so the patched server loads.
   - Make every expert resident with `--set vram-experts-gb=<GB>` (all 3,072 Inkling experts need about 14.8 GB; use 16). The engine log line `experts=<N> GPU0 ... / <M> host` must show M = 0.
   - Use `--parallel 2` with the router patch when the card has at least 8 GB free after the experts; use `--parallel 1` on smaller cards (see Gotchas).
6. **HTTPS.** Amp calls Custom URLs from its own servers and rejects plain `http://IP:port`. Use Tailscale Funnel on the pod. The tailnet needs MagicDNS and HTTPS certificates on, and a tag (default `tag:simplepod-model`, override with `TS_TAG`) that has the `funnel` node attribute.
   - `scripts/mint-tailscale-key.sh <file>` mints a one-use, ephemeral, preauthorized key with that tag, valid one hour.
   - `scripts/sp.sh ssh <id> 'cat > /root/pod-funnel.sh' < scripts/pod-funnel.sh`, then `scripts/sp.sh ssh <id> 'bash /root/pod-funnel.sh <hostname> <tag>' < <file>`, then delete `<file>`.
   - Verify from outside: `curl -sv https://<hostname>.<tailnet>.ts.net/v1/models` shows `SSL certificate verify ok` and HTTP 401 without a key. A new name can take a minute.
   - To move a name to a new pod, run `tailscale funnel reset` and `tailscale logout` on the old pod first (this frees the name; the ephemeral node disappears), then bring the new pod up with the same hostname. The Amp connection then needs no change.
7. **Verify the endpoint** with the key, through the HTTPS URL: `/health` (Strata: `loaded: true` and `max_context`), `/v1/models` (the served model ID), a chat completion, a tool call (`finish_reason: tool_calls`), SSE streaming ending in `[DONE]`, and a wrong or missing key returning 401.
8. **Add it to Amp.** Use `manage_amp` topic `model_providers` operation `create` with type `model_provider_custom_url`, or, in a multiplayer thread where that is blocked, give the user these values for Settings → Model Routing → Add → Custom URL:
   - Base URL `https://<hostname>.<tailnet>.ts.net/v1`, API format OpenAI Chat Completions (`chat-completions`), API key = the endpoint key.
   - Model mapping `<provider>/<model-name> -> <served model ID>`, for example `atomicchat/inkling-2-mini-uncensored -> inkling-2-mini-sq-15`.
   - Model Metadata Overrides for that ID: Input Tokens, Output Tokens 16384, Tools Yes, image input off unless vision is served. Set Input Tokens to at most 250 × the measured cold prefill tokens/s (Inkling at ~300 tok/s: 65536). Amp was observed to abandon a request after about 300 s, so a larger window makes cold reads of long threads fail and retry.
   - Activate the connection, run Check Access, then Settings → Model Selector → Add Model to put it in Top Models.
9. **Prove it in Amp.** The user starts a new thread on the model and sends a prompt. Read the server's `/metrics` (below) to confirm the request arrived and finished `stop`. Report the thread link and output.

## Checking health and speed

Read-only: `scripts/sp.sh ssh <id> 'bash -s' < scripts/pod-strata-report.sh` prints each request's prompt tokens, reused (cached) tokens, time to first token, decode tokens/s and finish reason, the slot contents, cancelled requests, expert placement, VRAM, and Funnel proxy errors. Healthy means: every request finished `stop` or `length`, later turns of a thread reuse nearly all their prompt (time to first token about a second), no `cancel=True` lines, no Funnel `proxy error`, and `/ 0 host` experts. `TLS handshake error ... EOF` lines from Tailscale relay addresses are probes, not failures. Also report `scripts/sp.sh summary` (balance, price per hour, hours left).

Where time goes: cold prompt reading on Strata runs about 300 tokens/s for Inkling even on an A100, so the first turn of a 45k-token Amp thread takes about 150 s. Later turns are fast only if the server still holds that thread's prefix. A slow later turn means the cache was evicted; look at which request ran in between.

## Stopping

After approval: `scripts/sp.sh delete <id>`. That ends billing and deletes the disk, including the downloaded model; the ephemeral Tailscale node removes itself. Confirm with `scripts/sp.sh summary` that no Docker instance remains. Tell the user to deactivate the Custom URL connection, or Amp threads on that model will fail.

## Gotchas

- Strata 0.2.21's router (`~/.local/share/strata/terminal/<version>/serve/server.py`, `_inkling_route`) sends a new conversation to a spare slot only if its prompt is under 2,048 tokens; anything longer takes slot 0 and wipes the cached main thread. Amp's side requests are 3–11k tokens, so every main-thread turn re-read 42k tokens (150 s). `scripts/pod-patch-strata-router.sh` changes that one line. Measured: the next turn after an interleaved request went from 61.7 s to 0.59 s.
- The patch and Tailscale live only in the running container. A Strata restart keeps the patch but not Funnel; recreating the instance loses both. Reapply them after any recreate.
- `strata launch --restart` with unchanged settings keeps the old server process. Use `scripts/pod-strata-launch.sh`, which runs `strata launch --stop` first.
- `--parallel 2` on a 24 GB card cut the prefill chunk to 512 tokens and moved host-RAM experts to the CPU; decode stalled at 0 tok/s. Two slots need the experts resident and VRAM to spare.
- A new server starts with an empty cache, so the first turn of a long existing thread has to read its whole prompt. A 101,756-token Inkling thread needed about 330 s on an A100, and Amp cancelled it at about 300 s twice. The third attempt reused 90,112 tokens that the cancelled reads had left behind and answered in 48 s, about 15 minutes after the move. The Input Tokens cap does not shorten a thread that is already longer. After moving servers, expect this, or start long threads fresh.
- Cloudflare quick tunnels (`cloudflared tunnel --url`) returned HTTP 429 twice; use Funnel.
- llama.cpp `server-cuda` (b12723) served Inkling, but on a 3090 a 64k or larger context ran out of memory or dropped decode to about 4 tok/s. Strata was faster for Inkling. For other models llama.cpp is still a valid default: image `ghcr.io/ggml-org/llama.cpp:server-cuda`, `--jinja -ngl 99 -fa on`, key from `LLAMA_API_KEY`.
- SimplePod console output is base64 in `.console` and stops showing a start script's output after the image banner; read `/var/log/strata-boot.log` over SSH instead.
- Reboot is `PATCH /instances/reboot` with content type `application/merge-patch+json`; POST returns 405.
