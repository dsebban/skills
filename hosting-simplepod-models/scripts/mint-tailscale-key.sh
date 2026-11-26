#!/usr/bin/env bash
# Usage: mint-tailscale-key.sh <output-file>
# Mints a one-use, ephemeral, preauthorized Tailscale auth key with tag TS_TAG (default tag:simplepod-model; the tag
# must exist and have the funnel node attribute), valid one hour. Writes only the key to <output-file> (mode 600)
# and never prints it. Needs TAILSCALE_API_KEY. Delete the file after the pod has joined.
set -euo pipefail
[ "${1:-}" ] && [ "$1" != -h ] && [ "$1" != --help ] || { sed -n 2,5p "$0"; exit 1; }
[ -n "${TAILSCALE_API_KEY:-}" ] || { echo "TAILSCALE_API_KEY is not set" >&2; exit 2; }
umask 077
TAG=${TS_TAG:-tag:simplepod-model}
curl -sfS -X POST -H "Authorization: Bearer $TAILSCALE_API_KEY" -H 'Content-Type: application/json' \
  https://api.tailscale.com/api/v2/tailnet/-/keys \
  -d "$(jq -nc --arg t "$TAG" '{capabilities:{devices:{create:{reusable:false,ephemeral:true,preauthorized:true,tags:[$t]}}},expirySeconds:3600,description:"simplepod model funnel"}')" \
  | jq -r '.key // empty' > "$1"
[ -s "$1" ] && echo "auth key written to $1" || { echo "minting failed" >&2; exit 1; }
