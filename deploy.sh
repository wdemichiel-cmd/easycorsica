#!/bin/bash
# Deploiement + auto-sync EasyCorsica -> http://IP/easycorsica
set -e
sudo mkdir -p /var/www/easycorsica
command -v rsync >/dev/null || sudo apt-get install -y -qq rsync

TMP=$(mktemp -d)
curl -fsSL https://codeload.github.com/wdemichiel-cmd/easycorsica/tar.gz/refs/heads/main | tar xz -C "$TMP" --strip-components=1
sudo rsync -a --delete --exclude deploy.sh "$TMP"/ /var/www/easycorsica/
rm -rf "$TMP"

CONF=$(grep -rl "default_server" /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
[ -z "$CONF" ] && CONF=$(ls /etc/nginx/sites-enabled/* 2>/dev/null | head -1)
if ! sudo grep -q "location /easycorsica" "$CONF"; then
  sudo sed -i '0,/server_name[^;]*;/s||&\n\n    location /easycorsica {\n        alias /var/www/easycorsica;\n        index index.html;\n    }|' "$CONF"
fi
sudo nginx -t && sudo systemctl reload nginx

# Auto-sync : le serveur se met a jour tout seul toutes les 10 min
sudo tee /usr/local/bin/easycorsica-sync >/dev/null <<'SYNC'
#!/bin/bash
set -e
TMP=$(mktemp -d)
curl -fsSL https://codeload.github.com/wdemichiel-cmd/easycorsica/tar.gz/refs/heads/main | tar xz -C "$TMP" --strip-components=1
rsync -a --delete --exclude deploy.sh "$TMP"/ /var/www/easycorsica/
rm -rf "$TMP"
SYNC
sudo chmod +x /usr/local/bin/easycorsica-sync
echo "*/10 * * * * root /usr/local/bin/easycorsica-sync >/dev/null 2>&1" | sudo tee /etc/cron.d/easycorsica-sync >/dev/null

echo "=== OK -> http://$(curl -s -4 ifconfig.me)/easycorsica (auto-sync toutes les 10 min) ==="
