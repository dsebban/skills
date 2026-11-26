# Worked example: Inkling-2-Mini-Uncensored on SimplePod (November 2026)

Model: `AtomicChat/Inkling-2-Mini-Uncensored-GGUF`, file `Inkling-2-Mini-Uncensored-AD-Q4_K.gguf` (16,525,559,776 bytes, sha256 `36e99f1f56ca33cb356f19d7e3822938f65af1cde978ad13170238928d4c955f`). 26B MoE, 3.4B active, looped core (`inkling2_loop`), 3,072 experts. Needs llama.cpp b12600+ or Strata 0.2.21 (family `inkling-2-mini`; Strata serves it under the ID `inkling-2-mini-sq-15` even when loading this file).

## Final setup

- One A100-SXM4-40GB (driver 615, CUDA 13.4): $0.42/h GPU + $0.017/h for an 80 GB disk = $0.437/h. The first attempt used an RTX 3090 24 GB at $0.16/h + disk = $0.177/h.
- Strata 0.2.21 with `--context 128k --parallel 2 --set vram-experts-gb=16 --vision off --tune skip`, router patch applied.
- HTTPS: `https://<hostname>.<tailnet>.ts.net/v1` through Tailscale Funnel on the pod.
- Amp: personal Custom URL connection, mapping `atomicchat/inkling-2-mini-uncensored -> inkling-2-mini-sq-15`, Output 16384, Tools Yes. Input Tokens was first set to 114688; three cold reads of 91k–98k tokens were then cancelled after ~300 s, so use 65536.

## Measured

- Cold prefill: ~290 tok/s on the RTX 3090 (experts partly in host RAM), ~310 tok/s on the A100 (all resident). A 45,639-token first turn took 150 s to the first token.
- Cached later turns: 46k–64k-token prompts reused all but 25–3,000 tokens; time to first token 0.3–4 s, median about 0.6 s. Over one working session, 257 of 260 requests finished normally.
- Decode: 72 tok/s at short context on the 3090 when cold experts were copied to the card, 54 tok/s when they ran on the CPU; 67 tok/s at short context and ~53 tok/s at 48k context on the A100.
- Funnel added about 0.28 s per request (0.31 s vs 0.03 s direct).

## What went wrong, in order

1. llama.cpp `ghcr.io/ggml-org/llama.cpp:server-cuda` (b12723) on the 3090: fine at 2 × 32k slots (33–42 tok/s), out of memory at 128k (`cudaMalloc failed` for a 12.9 GB compute buffer), a `cudaGraphInstantiate` crash at 64k, and about 4 tok/s decode at 48k with one slot. Replaced by Strata.
2. Saving instance env vars with `PUT /instances/{id}` sometimes recreated the container (new model download) and sometimes did nothing until a reboot. Editing the template while the instance ran also recreated it.
3. Downloading the GGUF with one `curl` connection stalled at 11 GB (0 MB/s). `aria2c -x 16` finished at ~85 MiB/s.
4. Amp rejected `http://IP:port` as a Custom URL. Cloudflare quick tunnels returned HTTP 429 twice. Tailscale Funnel with a minted ephemeral key worked.
5. `manage_amp` model provider calls are blocked in multiplayer Amp threads; the user added the connection in Settings.
6. Reading an older template with `sp_get_template` printed its stored API key into the thread; the key had to be rotated.
7. Slowness in Amp: with `--parallel 1`, Amp's 3–11k-token side requests evicted the 42k-token main thread, so every turn re-read the whole prompt (147–150 s). `--parallel 2` on the 3090 cut the prefill chunk to 512 tokens and stalled decode at 0 tok/s; reverted. On the A100, two slots alone still missed the cache (61.7 s) until the router patch (0.59 s, 19,034 tokens reused).
8. Restarts dropped requests: 14 were refused through Funnel during one ~90 s restart. Tell the user before restarting and ask them to retry failed turns.
9. Strata's default expert pool (11.48 GB) left 509 experts in host RAM even on the A100 with 25 GB free; `--set vram-experts-gb=16` fixed it.
