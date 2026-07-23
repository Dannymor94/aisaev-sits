#!/usr/bin/env bash
set -euo pipefail

rsync -avz --delete \
  --exclude '.DS_Store' \
  --exclude '*.md' \
  --exclude 'Ты_не_поломан*' \
  -e "ssh -p 2222 -i ~/.ssh/vnedrum" \
  ./site/ root@147.45.251.134:/srv/www/isaev/

ssh -p 2222 -i ~/.ssh/vnedrum root@147.45.251.134 \
  'caddy reload --config /srv/caddy/Caddyfile'
