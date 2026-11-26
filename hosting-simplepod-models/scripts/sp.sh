#!/usr/bin/env bash
# SimplePod API helper. Needs SIMPLEPOD_API_TOKEN in the environment; never prints it or the endpoint key.
set -euo pipefail
API=https://api.simplepod.ai
usage() {
  cat <<'EOF'
Usage: sp.sh <command> [args]
  summary                                   balance, price per hour, hours left, active instance count
  status <id> [console-chars]               status, ports, GPU memory, and the console tail (base64-decoded)
  endpoint <id>                             http://IP:PORT for container port 8080
  ssh <id> [remote command...]              SSH as root (password = instance hashId, read from the API); stdin is forwarded
  create <market-id> <template-id> <KEY_ENV> [NAME=VALUE ...]
                                            rent one GPU; the endpoint key is read from env var KEY_ENV and passed
                                            to the instance as STRATA_API_KEY and LLAMA_API_KEY; extra NAME=VALUE
                                            pairs become instance env vars (for example MODEL_URL=...)
  delete <id>                               delete the instance (ends billing, erases its disk)
Rent and delete only with the user's approval.
EOF
}
[ -n "${SIMPLEPOD_API_TOKEN:-}" ] || { echo "SIMPLEPOD_API_TOKEN is not set; add it as a secret" >&2; exit 2; }
get() { curl -sfS "$API$1" -H "X-AUTH-TOKEN: $SIMPLEPOD_API_TOKEN" -H 'Accept: application/json'; }
cmd=${1:-}; shift || true
case "$cmd" in
  summary)
    get /instances/summary | jq -c '{dockerActive: .all.active.rriDockerActiveCount, vmActive: .all.active.rriVmActiveCount, perHour: .rentalAvailability.pricePerTotal, balance: .rentalAvailability.balanceRental, hoursLeft: .rentalAvailability.availableRentalHours}' ;;
  status)
    j=$(get "/instances/$1")
    echo "$j" | jq -c '{id, name, status, gpuModel, pricePerGpu, gpuMemUsed, ports: [.ports.direct[]? | {service, srcPort, destPort, ip, protocol}], errors: .rigRentalInstanceErrors}'
    echo "$j" | jq -r '.console // ""' | base64 -d 2>/dev/null | tail -c "${2:-1500}" ;;
  endpoint)
    get "/instances/$1" | jq -r '.ports.direct[] | select(.srcPort==8080 or .srcPort=="8080") | "http://\(.ip):\(.destPort)"' ;;
  ssh)
    id=$1; shift
    j=$(get "/instances/$id")
    ip=$(echo "$j" | jq -r '.ports.direct[] | select(.service=="ssh") | .ip')
    port=$(echo "$j" | jq -r '.ports.direct[] | select(.service=="ssh") | .destPort')
    [ -n "$port" ] || { echo "no ssh port yet; the template must enable SSH and expose 22" >&2; exit 1; }
    command -v sshpass >/dev/null || sudo apt-get install -y -qq sshpass >/dev/null
    SSHPASS=$(echo "$j" | jq -r .hashId) sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o LogLevel=ERROR -o ConnectTimeout=15 -p "$port" "root@$ip" "$@" ;;
  create)
    market=$1 tpl=$2 keyenv=$3; shift 3
    key=${!keyenv:-}; [ -n "$key" ] || { echo "env var $keyenv is empty; create the secret first" >&2; exit 2; }
    env='[]'
    env=$(jq -c --arg k "$key" '. + [{name:"STRATA_API_KEY",value:$k},{name:"LLAMA_API_KEY",value:$k}]' <<<"$env")
    for kv in "$@"; do env=$(jq -c --arg n "${kv%%=*}" --arg v "${kv#*=}" '. + [{name:$n,value:$v}]' <<<"$env"); done
    body=$(jq -nc --arg m "/instances/market/$market" --arg t "/instances/templates/$tpl" --argjson e "$env" \
      '{instanceMarket:$m, instanceTemplate:$t, gpuCount:1, envVariables:$e}')
    curl -sS -X POST "$API/instances" -H "X-AUTH-TOKEN: $SIMPLEPOD_API_TOKEN" -H 'Content-Type: application/json' \
      -H 'Accept: application/json' -d "$body" | jq -c '{id, name, supportId, gpuModel, pricePerGpu, detail, title}' ;;
  delete)
    curl -sS -X DELETE "$API/instances/$1" -H "X-AUTH-TOKEN: $SIMPLEPOD_API_TOKEN" -o /dev/null -w 'DELETE %{http_code}\n' ;;
  *) usage; [ "$cmd" = -h ] || [ "$cmd" = --help ] || exit 1 ;;
esac
