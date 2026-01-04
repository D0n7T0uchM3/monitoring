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
echo -e "${YELLOW}Step 1: Starting nginx for ACME challenge...${NC}"

# Create a temporary nginx config for initial certificate
cat > nginx/conf.d/temp-acme.conf << 'EOF'
server {
    listen 80;
    server_name _;
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

# Temporarily disable SSL config
if [ -f nginx/conf.d/ssl.conf ]; then
    mv nginx/conf.d/ssl.conf nginx/conf.d/ssl.conf.disabled
fi
if [ -f nginx/conf.d/monitoring.conf ]; then
    mv nginx/conf.d/monitoring.conf nginx/conf.d/monitoring.conf.disabled
fi

# Start nginx
docker-compose up -d nginx

echo ""
echo -e "${YELLOW}Step 2: Requesting certificate from Let's Encrypt...${NC}"

# Request certificate
docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN"

echo ""
echo -e "${YELLOW}Step 3: Configuring nginx for HTTPS...${NC}"

# Remove temporary config
rm -f nginx/conf.d/temp-acme.conf

# Re-enable SSL config and update domain
if [ -f nginx/conf.d/ssl.conf.disabled ]; then
    # Replace domain placeholder with actual domain
    sed "s/\${DOMAIN}/$DOMAIN/g" nginx/conf.d/ssl.conf.disabled > nginx/conf.d/ssl.conf
    rm -f nginx/conf.d/ssl.conf.disabled
fi

# Keep monitoring.conf disabled (ssl.conf handles everything)
# rm -f nginx/conf.d/monitoring.conf.disabled

# Restart nginx with SSL
docker-compose restart nginx

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}SSL Certificate successfully installed!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "Your monitoring stack is now available at:"
echo -e "  ${YELLOW}https://$DOMAIN/grafana${NC}     - Grafana"
echo -e "  ${YELLOW}https://$DOMAIN/prometheus${NC}  - Prometheus"
echo -e "  ${YELLOW}https://$DOMAIN/loki${NC}        - Loki"
echo ""
echo -e "${YELLOW}Note:${NC} Update your .env file:"
echo "  GRAFANA_ROOT_URL=https://$DOMAIN/grafana"
echo "  PROMETHEUS_EXTERNAL_URL=https://$DOMAIN/prometheus/"
echo ""
echo -e "${YELLOW}Certificate auto-renewal:${NC}"
echo "  Certbot container automatically renews certificates every 12 hours"
echo ""

