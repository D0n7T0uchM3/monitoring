#!/bin/bash

# =============================================================================
# Let's Encrypt SSL Certificate Initialization Script
# =============================================================================
# This script obtains the initial SSL certificate from Let's Encrypt
# Run this ONCE before starting the full stack with HTTPS
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

# Check required variables
if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "monitoring.example.com" ]; then
    echo -e "${RED}Error: Please set DOMAIN in .env file${NC}"
    echo "Example: DOMAIN=monitoring.yourdomain.com"
    echo -e "${RED}Note: Do NOT include https:// - just the domain name${NC}"
    exit 1
fi

# Check if DOMAIN contains protocol (common mistake)
if [[ "$DOMAIN" == *"://"* ]]; then
    echo -e "${RED}Error: DOMAIN should not contain protocol (http:// or https://)${NC}"
    echo "Current value: $DOMAIN"
    echo "Correct format: DOMAIN=monitoring.yourdomain.com"
    exit 1
fi

if [ -z "$CERTBOT_EMAIL" ] || [ "$CERTBOT_EMAIL" = "admin@example.com" ]; then
    echo -e "${RED}Error: Please set CERTBOT_EMAIL in .env file${NC}"
    echo "Example: CERTBOT_EMAIL=your-email@example.com"
    exit 1
fi

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}Let's Encrypt Certificate Initialization${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "Domain: ${YELLOW}$DOMAIN${NC}"
echo -e "Email:  ${YELLOW}$CERTBOT_EMAIL${NC}"
echo ""

# Confirm
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 1: Preparing nginx for ACME challenge...${NC}"

# Backup and disable existing configs
if [ -f nginx/conf.d/ssl.conf ]; then
    mv nginx/conf.d/ssl.conf nginx/conf.d/ssl.conf.disabled
fi
if [ -f nginx/conf.d/monitoring.conf ]; then
    mv nginx/conf.d/monitoring.conf nginx/conf.d/monitoring.conf.disabled
fi

# Create a temporary nginx config for initial certificate
cat > nginx/conf.d/acme.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'Waiting for SSL certificate...';
        add_header Content-Type text/plain;
    }
}
EOF

# Stop everything first
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Start nginx
echo -e "${YELLOW}Starting nginx...${NC}"
docker compose up -d nginx 2>/dev/null || docker-compose up -d nginx

# Wait for nginx to be ready
sleep 3

echo ""
echo -e "${YELLOW}Step 2: Requesting certificate from Let's Encrypt...${NC}"

# Request certificate (override entrypoint to run certonly instead of renew loop)
docker compose run --rm --entrypoint "certbot" certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN" \
    2>/dev/null || \
docker-compose run --rm --entrypoint "certbot" certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"

echo ""
echo -e "${YELLOW}Step 3: Configuring nginx for HTTPS...${NC}"

# Remove temporary config
rm -f nginx/conf.d/acme.conf

# Re-enable SSL config and replace domain placeholder
if [ -f nginx/conf.d/ssl.conf.disabled ]; then
    sed "s/\${DOMAIN}/$DOMAIN/g" nginx/conf.d/ssl.conf.disabled > nginx/conf.d/ssl.conf
    rm -f nginx/conf.d/ssl.conf.disabled
fi

# Remove monitoring.conf (ssl.conf handles everything in HTTPS mode)
rm -f nginx/conf.d/monitoring.conf.disabled

# Restart everything
echo -e "${YELLOW}Starting full stack...${NC}"
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
docker compose up -d 2>/dev/null || docker-compose up -d

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}SSL Certificate successfully installed!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "Your monitoring stack is now available at:"
echo -e "  ${YELLOW}https://$DOMAIN/grafana${NC}     - Grafana"
echo -e "  ${YELLOW}https://$DOMAIN/prometheus${NC}  - Prometheus (requires auth)"
echo -e "  ${YELLOW}https://$DOMAIN/loki${NC}        - Loki (requires auth)"
echo ""
echo -e "${YELLOW}Don't forget to:${NC}"
echo "  1. Create .htpasswd for Prometheus/Loki auth:"
echo "     htpasswd -c nginx/.htpasswd admin"
echo ""
echo "  2. Update your .env file:"
echo "     GRAFANA_ROOT_URL=https://$DOMAIN/grafana"
echo "     PROMETHEUS_EXTERNAL_URL=https://$DOMAIN/prometheus/"
echo ""
echo -e "${YELLOW}Certificate auto-renewal:${NC}"
echo "  Certbot container automatically renews certificates every 12 hours"
echo ""
