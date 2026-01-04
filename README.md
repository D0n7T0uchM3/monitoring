# Prometheus + Grafana + Loki

## 🚀 Быстрый старт

```bash
# Скопируйте файл с переменными окружения и настройте
cp env.example .env

# Отредактируйте .env и задайте безопасные пароли
vim .env

# Запустите все сервисы
docker-compose up -d

# Проверьте статус
docker-compose ps

# Просмотр логов
docker-compose logs -f
```

## ⚙️ Настройка переменных окружения

Перед запуском скопируйте `env.example` в `.env` и настройте значения:

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `DOMAIN` | Домен для HTTPS | monitoring.example.com |
| `CERTBOT_EMAIL` | Email для Let's Encrypt | admin@example.com |
| `GRAFANA_ADMIN_USER` | Имя администратора Grafana | admin |
| `GRAFANA_ADMIN_PASSWORD` | Пароль администратора Grafana | admin |
| `GRAFANA_ROOT_URL` | Внешний URL Grafana | http://localhost/grafana |
| `PROMETHEUS_RETENTION_TIME` | Время хранения метрик | 15d |
| `PROMETHEUS_EXTERNAL_URL` | Внешний URL Prometheus | http://localhost/prometheus/ |
| `LOKI_INGESTION_RATE_MB` | Лимит скорости приёма логов (МБ/с) | 16 |
| `LOKI_INGESTION_BURST_SIZE_MB` | Лимит пиковой нагрузки (МБ) | 24 |

## 📊 Точки доступа

Все сервисы доступны через Nginx на порту 80:

| Сервис     | URL                          | Авторизация                    |
|------------|------------------------------|--------------------------------|
| Grafana    | http://localhost/grafana     | Логин Grafana (см. .env)       |
| Prometheus | http://localhost/prometheus  | Basic Auth (nginx/.htpasswd)   |
| Loki       | http://localhost/loki        | Basic Auth (nginx/.htpasswd)   |
| Health     | http://localhost/health      | -                              |

> **Примечание:** Prometheus и Loki защищены Basic Auth через Nginx. По умолчанию: `admin` / `admin`

## 🏗️ Архитектура

```
                                        ┌─────────────┐
                                        │    Nginx    │
                                        │   (прокси)  │
                                        └──────┬──────┘
                                               │
              ┌────────────────────────────────┼────────────────────────────────┐
              │                                │                                │
              ▼                                ▼                                ▼
┌─────────────────────┐          ┌─────────────────────┐          ┌─────────────────────┐
│      Grafana        │          │     Prometheus      │          │        Loki         │
│   (визуализация)    │◀─────────│   (сбор метрик)     │          │   (хранение логов)  │
└─────────────────────┘          └─────────────────────┘          └─────────────────────┘
                                          ▲                                ▲
                                          │                                │
┌─────────────────────┐          ┌────────┴────────┐             ┌─────────┴─────────┐
│   Ваши приложения   │──────────│    /metrics     │             │     Promtail      │
│                     │          └─────────────────┘             │   (коллектор)     │
└─────────────────────┘                                          └───────────────────┘
```

## ⚙️ Конфигурация

### Добавление метрик приложения

Отредактируйте `prometheus/prometheus.yml` для добавления вашего приложения:

```yaml
scrape_configs:
  - job_name: "my-application"
    static_configs:
      - targets: ["app-host:8080"]
    metrics_path: /metrics
```

Затем перезагрузите Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```
