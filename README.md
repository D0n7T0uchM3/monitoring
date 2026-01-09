# Prometheus + Grafana + Loki

## 🚀 Быстрый старт

```bash
# переменные окружения
cp env.example .env
vim .env

# DOMAIN=monitoring.yourdomain.com
# CERTBOT_EMAIL=your@email.com

# файл с паролем для Basic Auth
htpasswd -c nginx/.htpasswd admin

# скрипт получения SSL-сертификата
chmod +x scripts/init-letsencrypt.sh
./scripts/init-letsencrypt.sh
```
