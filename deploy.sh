#!/bin/bash
# Deploiement EasyCorsica -> http://IP/easycorsica
# A executer SUR le serveur (sudo requis)
set -e
TOKEN="$1"
[ -z "$TOKEN" ] && { echo "usage: sudo bash deploy.sh <github_token>"; exit 1; }

sudo mkdir -p /var/www/easycorsica
sudo curl -fsSL -H "Authorization: Bearer $TOKEN" \
  "https://raw.githubusercontent.com/wdemichiel-cmd/easycorsica/main/index.html" \
  -o /var/www/easycorsica/index.html

# Trouver le vhost qui sert l'IP (default_server ou premier site actif)
CONF=$(grep -rl "default_server" /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
[ -z "$CONF" ] && CONF=$(ls /etc/nginx/sites-enabled/* 2>/dev/null | head -1)
echo "vhost cible: $CONF"

if ! grep -q "location /easycorsica" "$CONF"; then
  sudo sed -i '0,/server_name[^;]*;/s||&\n\n    location /easycorsica {\n        alias /var/www/easycorsica;\n        index index.html;\n        try_files $uri $uri/ /easycorsica/index.html;\n    }|' "$CONF"
fi
sudo nginx -t && sudo systemctl reload nginx
echo "OK -> http://$(curl -s -4 ifconfig.me)/easycorsica"
