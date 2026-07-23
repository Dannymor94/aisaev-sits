# DEPLOY.md — деплой и домен

## Инфраструктура

| Что | Значение |
|---|---|
| VPS | Timeweb, `147.45.251.134` |
| SSH | порт `2222`, ключ `~/.ssh/vnedrum` (ed25519) |
| Веб-сервер | Caddy 2.11.4 |
| Корень сайта | `/srv/www/isaev` |
| Конфиг | `/srv/caddy/Caddyfile` |
| Стенд | `isaev.vnedrum.ru` (wildcard уже настроен) |
| Прод | `isaev-yoga.ru` (регистратор — рег.ру) |

---

## Caddyfile

**Стенд:**

```
isaev.vnedrum.ru {
    root * /srv/www/isaev
    encode zstd gzip
    try_files {path} {path}/index.html {path}.html
    file_server
    header /assets/* Cache-Control "public, max-age=31536000, immutable"
}
```

**Прод (добавить на M7):**

```
isaev-yoga.ru {
    redir https://www.isaev-yoga.ru{uri} permanent
}

www.isaev-yoga.ru {
    root * /srv/www/isaev
    encode zstd gzip
    try_files {path} {path}/index.html {path}.html
    file_server
    header /assets/* Cache-Control "public, max-age=31536000, immutable"
}
```

Перезагрузка без даунтайма:

```bash
ssh -p 2222 -i ~/.ssh/vnedrum root@147.45.251.134 \
  'caddy reload --config /srv/caddy/Caddyfile'
```

---

## Деплой

```bash
#!/usr/bin/env bash
# deploy.sh
set -euo pipefail

SRC="./site/"
DST="root@147.45.251.134:/srv/www/isaev/"

rsync -avz --delete \
  --exclude '.DS_Store' \
  --exclude '*.md' \
  --exclude 'Ты_не_поломан*' \
  -e "ssh -p 2222 -i ~/.ssh/vnedrum" \
  "$SRC" "$DST"

ssh -p 2222 -i ~/.ssh/vnedrum root@147.45.251.134 \
  'caddy reload --config /srv/caddy/Caddyfile'
```

> ⚠️ `--delete` сносит на сервере всё, чего нет локально. Полная книга не должна
> лежать в `site/` — исключение по имени стоит на всякий случай, но это не защита.
> Держать книгу в другой директории.

Проверка перед первым деплоем:

```bash
find ./site -name "*.pdf" -exec ls -lh {} \;
# должен быть только assets/files/fragment.pdf, ~1 МБ
```

---

## Переключение домена (M7)

Порядок важен. Ломается обычно на шаге 1.

### 1. Правило

> **Меняем только A-записи. NS не трогаем.**

При смене A-записей почта на домене продолжает работать — за неё отвечают отдельные
MX-записи. Перевод NS на другие серверы сносит зону целиком, вместе с почтой.

### 2. За сутки

В панели рег.ру → «Управление зоной DNS»: снизить **TTL на A-записях до 300**.
Это делает откат быстрым.

Проверить, что отключены «Парковка» и «Перенаправление» — иначе записи не применятся.

### 3. Переключение

Добавить блок в Caddyfile, затем в рег.ру:

| Тип | Имя | Значение | TTL |
|---|---|---|---|
| A | @ | `147.45.251.134` | 300 |
| A | www | `147.45.251.134` | 300 |

### 4. Проверка

```bash
dig +short isaev-yoga.ru @8.8.8.8
dig +short www.isaev-yoga.ru @8.8.8.8
# должны вернуть 147.45.251.134

dig +short MX isaev-yoga.ru @8.8.8.8
# сравнить с тем, что было ДО переключения — не должно измениться
```

Сертификат Let's Encrypt выпустится сам, когда DNS разойдётся. Требования:
порты **80 и 443** открыты (80 нужен для ACME-челленджа).

Если сертификат не выпускается — смотреть:

```bash
journalctl -u caddy -n 100 --no-pager
```

### 5. После

- Старый хостинг **не отключать минимум неделю** — на случай отката
- Через неделю вернуть TTL на 3600
- Проверить `https://isaev-yoga.ru/karta` — адрес напечатан в книге

---

## Чек-лист запуска

- [ ] Автопродление домена включено
- [ ] Полной книги нет в `site/`
- [ ] Все ссылки ТГ/ВК реальные, ни одного `#telegram` / `#vk`
- [ ] Цены 1000 / 2000 ₽ на кнопках
- [ ] Кодовые слова в микрокопии
- [ ] `fragment.pdf` скачивается, последняя страница обновлена
- [ ] `/karta` открывается
- [ ] Метрика считает цели
- [ ] Ноль обращений к `fonts.googleapis.com`
- [ ] Проверено на телефоне, не только в эмуляторе
