#!/usr/bin/env bash
# Runs on the pod: copy it with  sp.sh ssh <id> 'cat > /root/pod-funnel.sh' < pod-funnel.sh
# then run  sp.sh ssh <id> 'bash /root/pod-funnel.sh <hostname> [tag]' < <auth-key-file>
# Installs Tailscale in userspace mode (containers have no TUN device), joins with the auth key from stdin as
# <hostname>, and publishes https://<hostname>.<tailnet>.ts.net -> 127.0.0.1:8080 with Funnel. TLS ends on the pod.
# Not persistent: rerun after a container restart (a new auth key is needed then).
set -e
H=${1:?hostname required}
TAG=${2:-tag:simplepod-model}
read -r TS_AUTHKEY
cd /root
if [ ! -x /root/ts/tailscaled ]; then
  curl -fsSL -o ts.tgz https://pkgs.tailscale.com/stable/tailscale_latest_amd64.tgz
  mkdir -p ts && tar xzf ts.tgz -C ts --strip-components=1 && rm ts.tgz
fi
S=--socket=/var/run/tailscale/tailscaled.sock
mkdir -p /var/lib/tailscale /var/run/tailscale
pgrep -x tailscaled >/dev/null || nohup /root/ts/tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state $S > /root/tailscaled.log 2>&1 < /dev/null &
sleep 3
/root/ts/tailscale $S up --authkey="$TS_AUTHKEY" --hostname="$H" --advertise-tags="$TAG" --accept-dns=false
unset TS_AUTHKEY
/root/ts/tailscale $S funnel --bg --https=443 http://127.0.0.1:8080
/root/ts/tailscale $S funnel status
/root/ts/tailscale $S status --self --peers=false | head -1
