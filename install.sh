#!/usr/bin/env bash
# Defense Swarm dedicated server -- one-command Linux VPS installer.
#
# One-liner (grabs the latest server build automatically):
#   curl -sSL https://raw.githubusercontent.com/TallblokeUK/defense-swarm-server/main/install.sh | sudo bash
#
# Or point it at a specific build / local binary:
#   sudo bash install.sh https://example.com/defense-swarm-server-linux.zip
#   sudo bash install.sh ./defense_swarm.x86_64
#
# Installs to /opt/defense-swarm, runs as its own user under systemd,
# opens the firewall (ufw, if present), then prints your web-admin link.
set -euo pipefail

DEFAULT_URL="https://raw.githubusercontent.com/TallblokeUK/defense-swarm-server/main/releases/defense-swarm-server-linux.zip"
SRC="${1:-$DEFAULT_URL}"
DIR=/opt/defense-swarm
BIN="$DIR/defense_swarm.x86_64"
SVC=defense-swarm
RUNUSER=swarm

if [[ $EUID -ne 0 ]]; then echo "run me with sudo"; exit 1; fi

echo "==> installing to $DIR"
id -u $RUNUSER &>/dev/null || useradd -r -m -d /home/$RUNUSER $RUNUSER
mkdir -p "$DIR"

if [[ "$SRC" == http* ]]; then
  echo "==> downloading $SRC"
  tmp=$(mktemp -d)
  curl -fsSL "$SRC" -o "$tmp/pkg"
  # Zip detection by magic bytes ("PK") -- the `file` tool is not
  # installed on minimal VPS images and its absence must not make us
  # install the archive as the binary.
  if [[ "$(head -c2 "$tmp/pkg")" == "PK" ]]; then
    # Minimal images ship without unzip AND with stale apt lists --
    # update before installing, and fall back to python3's zipfile.
    if ! command -v unzip &>/dev/null; then
      echo "==> installing unzip"
      apt-get -qq update >/dev/null 2>&1 || true
      apt-get -qq -y install unzip >/dev/null 2>&1 || true
    fi
    if command -v unzip &>/dev/null; then
      unzip -o "$tmp/pkg" -d "$DIR" >/dev/null
    elif command -v python3 &>/dev/null; then
      echo "==> unzip unavailable, extracting with python3"
      python3 -m zipfile -e "$tmp/pkg" "$DIR/"
    else
      echo "ERROR: cannot extract the server package (need unzip or python3)"
      exit 1
    fi
    found=$(find "$DIR" -maxdepth 2 -name '*.x86_64' | head -n1)
    [[ -n "$found" && "$found" != "$BIN" ]] && mv "$found" "$BIN"
  else
    mv "$tmp/pkg" "$BIN"
  fi
  rm -rf "$tmp"
else
  cp "$SRC" "$BIN"
  # The .pck rides beside the binary on non-embedded exports.
  [[ -f "${SRC%.x86_64}.pck" ]] && cp "${SRC%.x86_64}.pck" "${BIN%.x86_64}.pck" || true
fi
chmod +x "$BIN"
chown -R $RUNUSER:$RUNUSER "$DIR"

echo "==> writing systemd unit"
cat > /etc/systemd/system/$SVC.service <<EOF
[Unit]
Description=Defense Swarm dedicated server
After=network.target

[Service]
ExecStart=$BIN --headless -- --server
Restart=on-failure
User=$RUNUSER

[Install]
WantedBy=multi-user.target
EOF

if command -v ufw &>/dev/null; then
  echo "==> opening firewall (UDP 7777 game, TCP 8080 admin)"
  ufw allow 7777/udp >/dev/null || true
  ufw allow 8080/tcp >/dev/null || true
fi

# A one-word command for "what's my admin link?" -- nobody should
# ever be sent digging through a config file for the token.
cat > /usr/local/bin/swarm-admin <<'HELPER'
#!/usr/bin/env bash
CFG="/home/swarm/.local/share/godot/app_userdata/Defense Swarm/server.cfg"
TOKEN=$(grep -oP 'token="\K[^"]+' "$CFG" 2>/dev/null)
PUB=$(curl -4 -fsS -m 5 ifconfig.me 2>/dev/null)
URLHOST="$PUB"
if [[ -z "$PUB" ]]; then
  PUB=$(curl -6 -fsS -m 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
  [[ "$PUB" == *:* ]] && URLHOST="[$PUB]" || URLHOST="$PUB"
fi
if [[ -z "$TOKEN" ]]; then
  echo "server has not written its token yet -- is it running?"
  echo "  systemctl status defense-swarm"
  exit 1
fi
echo "Web admin:    http://$URLHOST:8080/?t=$TOKEN"
echo "Players join: $PUB  (UDP 7777)"
HELPER
chmod +x /usr/local/bin/swarm-admin

systemctl daemon-reload
systemctl enable --now $SVC
echo "==> waiting for first boot"

# Wait up to 30s for the server to boot and write its config (which
# holds the admin token) instead of hoping 5s is enough.
CFG="/home/$RUNUSER/.local/share/godot/app_userdata/Defense Swarm/server.cfg"
TOKEN=""
for i in $(seq 1 30); do
  TOKEN=$(grep -oP 'token="\K[^"]+' "$CFG" 2>/dev/null || true)
  [[ -n "$TOKEN" ]] && break
  sleep 1
done

# Public address: prefer IPv4 (every player can reach it); fall back
# to IPv6 in URL brackets, then to whatever the box reports locally.
PUB=$(curl -4 -fsS -m 5 ifconfig.me 2>/dev/null || true)
URLHOST="$PUB"
if [[ -z "$PUB" ]]; then
  PUB=$(curl -6 -fsS -m 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
  [[ "$PUB" == *:* ]] && URLHOST="[$PUB]" || URLHOST="$PUB"
fi

echo
echo "=============================================================="
if systemctl is-active --quiet $SVC; then
  echo " Defense Swarm server is RUNNING."
else
  echo " WARNING: the service is NOT running -- check:"
  echo "   journalctl -u $SVC -n 50"
fi
echo
if [[ -n "$TOKEN" ]]; then
  echo "   Web admin:   http://$URLHOST:8080/?t=$TOKEN"
else
  echo "   Web admin link not ready yet -- just run:  swarm-admin"
fi
echo "   Players join: $PUB  (UDP 7777)"
echo
echo " Lost the link? Type:  swarm-admin"
echo " Set a join password on the web admin page. Manage with:"
echo "   systemctl status $SVC     journalctl -u $SVC -f"
echo "=============================================================="
