#!/bin/bash
# SimplePod template start script (paste into sp_create_template startScript). Runs as root at container start.
# Instance env vars: MODEL_URL (required, a .gguf URL), STRATA_API_KEY (set by sp.sh create),
# STRATA_FAMILY (default inkling-2-mini), STRATA_ARGS (default below). Log: /var/log/strata-boot.log
exec > >(tee -a /var/log/strata-boot.log) 2>&1
echo "boot $(date -u +%Y-%m-%dT%H:%M:%SZ)"
ulimit -l unlimited || true
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq curl ca-certificates pciutils aria2
nvidia-smi || true
mkdir -p /root/strata-data/models/hf /root/.local/bin
curl -fsSL --connect-timeout 15 --retry 3 -o /tmp/install.sh https://github.com/Niko1221/Strata/releases/download/v0.2.21/install.sh
STRATA_FEED=https://github.com/Niko1221/Strata/releases/download/v0.2.21 sh /tmp/install.sh
export PATH="/root/.local/bin:$PATH"
D=/root/strata-data/models/hf; N=$(basename "${MODEL_URL%%\?*}"); F=$D/$N
# 16 connections: a single-connection curl from Hugging Face stalled at about 1 MB/s.
[ -e "$F.done" ] || { aria2c -c -x 16 -s 16 -k 64M --file-allocation=none --summary-interval=60 -d "$D" -o "$N" "$MODEL_URL" && touch "$F.done"; }
ls -la "$F"
strata launch --model-path "$F" --family "${STRATA_FAMILY:-inkling-2-mini}" \
  ${STRATA_ARGS:---context 128k --parallel 1 --vision off --tune skip} \
  --access lan --port 8080 --api-key-env STRATA_API_KEY --data-dir /root/strata-data --yes --no-tui
echo "launch exit $?"
sleep infinity
