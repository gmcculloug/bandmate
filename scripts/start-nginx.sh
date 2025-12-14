#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_CONF="${PROJECT_ROOT}/config/nginx-local.conf"
LOG_DIR="${PROJECT_ROOT}/nginx/logs"

echo -e "${BLUE}🚀 Starting nginx for Band Huddle local development${NC}"
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}❌ nginx is not installed${NC}"
    echo ""
    echo "To install nginx on macOS:"
    echo "  brew install nginx"
    echo ""
    echo "To install nginx on Ubuntu/Debian:"
    echo "  sudo apt-get update && sudo apt-get install nginx"
    echo ""
    exit 1
fi

# Check if configuration file exists
if [ ! -f "$NGINX_CONF" ]; then
    echo -e "${RED}❌ nginx configuration file not found: $NGINX_CONF${NC}"
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Check if SSL certificates exist
SSL_CERT="${PROJECT_ROOT}/ssl/server.crt"
SSL_KEY="${PROJECT_ROOT}/ssl/server.key"

if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
    echo -e "${YELLOW}⚠️  SSL certificates not found${NC}"
    echo "  Expected: $SSL_CERT"
    echo "  Expected: $SSL_KEY"
    echo ""
    echo "Run the certificate generation script first:"
    echo "  ./scripts/generate-certs.sh"
    echo ""
    exit 1
fi

# Test nginx configuration
echo -e "${YELLOW}🔍 Testing nginx configuration...${NC}"
if nginx -t -c "$NGINX_CONF"; then
    echo -e "${GREEN}✅ Configuration test passed${NC}"
else
    echo -e "${RED}❌ Configuration test failed${NC}"
    exit 1
fi

# Check if nginx is already running
echo ""
echo -e "${YELLOW}🔍 Checking if nginx is already running...${NC}"
if pgrep nginx > /dev/null; then
    echo -e "${YELLOW}⚠️  nginx is already running${NC}"
    echo ""
    echo "To stop the existing nginx process:"
    echo "  ./scripts/stop-nginx.sh"
    echo "  OR: nginx -s stop"
    echo ""
    echo "Then run this script again to start with the new configuration."
    exit 1
fi

# Start nginx with our configuration
echo -e "${YELLOW}🌟 Starting nginx...${NC}"
nginx -c "$NGINX_CONF"

# Give nginx a moment to start
sleep 2

# Check if nginx is running
if pgrep nginx > /dev/null; then
    echo -e "${GREEN}✅ nginx started successfully!${NC}"
    echo ""
    echo -e "${BLUE}📡 Your application is now available at:${NC}"
    echo "  • HTTPS: https://localhost"
    echo "  • HTTPS: https://band-huddle.local (add to /etc/hosts if needed)"
    echo ""
    echo -e "${YELLOW}💡 Make sure your Sinatra app is running on port 4567:${NC}"
    echo "  ruby app.rb"
    echo ""
    echo -e "${BLUE}📊 To monitor logs:${NC}"
    echo "  tail -f ${LOG_DIR}/access.log"
    echo "  tail -f ${LOG_DIR}/error.log"
    echo ""
    echo -e "${BLUE}🛑 To stop nginx:${NC}"
    echo "  nginx -s stop"
    echo "  OR: ./scripts/stop-nginx.sh"
else
    echo -e "${RED}❌ Failed to start nginx${NC}"
    echo ""
    echo "Check the error log for details:"
    echo "  tail ${LOG_DIR}/error.log"
    exit 1
fi