#!/bin/bash
# Deploiement + auto-sync EasyCorsica -> http://IP/easycorsica
set -e
sudo mkdir -p /var/www/easycorsica
command -v rsync >/dev/null || sudo apt-get install -y -qq rsync

TMP=$(mktemp -d)
curl -fsSL https://codeload.github.com/wdemichiel-cmd/easycorsica/tar.gz/refs/heads/main | tar xz -C "$TMP" --strip-components=1
sudo rsync -a --delete --exclude deploy.sh "$TMP"/ /var/www/easycorsica/
rm -rf "$TMP"
sudo chown -R www-data:www-data /var/www/easycorsica
sudo chmod 755 /var/www/easycorsica
sudo chmod -R a+rX /var/www/easycorsica

# --- Bloc nginx : on purge l'ancien (try_files bugue avec alias) puis on pose un propre
for f in /etc/nginx/sites-enabled/*; do
  sudo sed -i '/location \/easycorsica/,/^[[:space:]]*}/d' "$f"
  sudo sed -i '/location = \/easycorsica/,/^[[:space:]]*}/d' "$f" 2>/dev/null || true
done
CONF=$(grep -rl "default_server" /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
[ -z "$CONF" ] && CONF=$(ls /etc/nginx/sites-enabled/* 2>/dev/null | head -1)
echo ">>> vhost cible : $CONF"
sudo sed -i '0,/server_name[^;]*;/s||&\n\n    location = /easycorsica { return 301 /easycorsica/; }\n    location /easycorsica/ {\n        alias /var/www/easycorsica/;\n        index index.html;\n    }|' "$CONF"
sudo nginx -t && sudo systemctl reload nginx

# --- Auto-sync (fichiers uniquement, jamais d'execution de code du repo)
sudo tee /usr/local/bin/easycorsica-sync >/dev/null <<'SYNC'
#!/bin/bash
set -e
TMP=$(mktemp -d)
curl -fsSL https://codeload.github.com/wdemichiel-cmd/easycorsica/tar.gz/refs/heads/main | tar xz -C "$TMP" --strip-components=1
rsync -a --delete --exclude deploy.sh "$TMP"/ /var/www/easycorsica/
rm -rf "$TMP"
chown -R www-data:www-data /var/www/easycorsica
chmod 755 /var/www/easycorsica
chmod -R a+rX /var/www/easycorsica
SYNC
sudo chmod +x /usr/local/bin/easycorsica-sync
echo "*/10 * * * * root /usr/local/bin/easycorsica-sync >/dev/null 2>&1" | sudo tee /etc/cron.d/easycorsica-sync >/dev/null

# --- Auto-diagnostic
echo ""
echo "===== DIAGNOSTIC ====="
echo "--- permissions (chaine complete) :"
namei -m /var/www/easycorsica/index.html || true
echo "--- config nginx active pour easycorsica :"
sudo nginx -T 2>/dev/null | grep -B2 -A6 "easycorsica" || echo "AUCUN bloc easycorsica dans la conf !"
echo "--- test en local :"
curl -s -o /dev/null -w "localhost/easycorsica/           -> %{http_code}\n" http://localhost/easycorsica/
curl -s -o /dev/null -w "localhost/easycorsica/index.html -> %{http_code}\n" http://localhost/easycorsica/index.html
echo "--- 5 dernieres erreurs nginx :"
sudo tail -5 /var/log/nginx/error.log 2>/dev/null || true
echo "===== FIN DIAGNOSTIC ====="
echo ""
echo "=== http://$(curl -s -4 ifconfig.me)/easycorsica/ (auto-sync actif) ==="
