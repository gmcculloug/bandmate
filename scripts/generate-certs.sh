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
SSL_DIR="${PROJECT_ROOT}/ssl"
SSL_CERT="${SSL_DIR}/server.crt"
SSL_KEY="${SSL_DIR}/server.key"

echo -e "${BLUE}🔐 Generating SSL certificates for local development${NC}"
echo ""

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}❌ OpenSSL is not installed${NC}"
    echo ""
    echo "To install OpenSSL on macOS:"
    echo "  brew install openssl"
    echo ""
    echo "To install OpenSSL on Ubuntu/Debian:"
    echo "  sudo apt-get update && sudo apt-get install openssl"
    echo ""
    exit 1
fi

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Check if certificates already exist
if [ -f "$SSL_CERT" ] && [ -f "$SSL_KEY" ]; then
    echo -e "${YELLOW}⚠️  SSL certificates already exist:${NC}"
    echo "  Certificate: $SSL_CERT"
    echo "  Private key: $SSL_KEY"
    echo ""

    # Check certificate expiration
    if openssl x509 -checkend 86400 -noout -in "$SSL_CERT" &>/dev/null; then
        echo -e "${GREEN}✅ Current certificate is valid for more than 24 hours${NC}"
        echo ""
        read -p "Do you want to regenerate the certificates anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}📋 Keeping existing certificates${NC}"
            echo ""
            echo -e "${BLUE}To view certificate details:${NC}"
            echo "  openssl x509 -in $SSL_CERT -text -noout | head -20"
            exit 0
        fi
    else
        echo -e "${YELLOW}⚠️  Current certificate expires within 24 hours${NC}"
        echo ""
    fi

    echo -e "${YELLOW}🔄 Backing up existing certificates...${NC}"
    cp "$SSL_CERT" "${SSL_CERT}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SSL_KEY" "${SSL_KEY}.backup.$(date +%Y%m%d_%H%M%S)"
fi

echo -e "${YELLOW}🔧 Generating new SSL certificates...${NC}"

# Generate private key
openssl genpkey -algorithm RSA -out "$SSL_KEY" -pkcs8 -pkeyopt rsa_keygen_bits:4096

# Generate certificate signing request configuration
cat > "${SSL_DIR}/server.conf" << EOF
[req]
default_bits = 4096
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=Development
L=Local
O=Band Huddle Local Development
OU=Development Team
CN=localhost

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = band-huddle.local
DNS.3 = *.band-huddle.local
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Generate certificate
openssl req -new -x509 -key "$SSL_KEY" -out "$SSL_CERT" -days 365 -config "${SSL_DIR}/server.conf" -extensions v3_req

# Set appropriate permissions
chmod 600 "$SSL_KEY"
chmod 644 "$SSL_CERT"

# Clean up temporary config file
rm "${SSL_DIR}/server.conf"

echo -e "${GREEN}✅ SSL certificates generated successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Certificate details:${NC}"
echo "  Certificate: $SSL_CERT"
echo "  Private key: $SSL_KEY"
echo "  Valid for: 365 days"
echo ""

# Show certificate details
echo -e "${BLUE}📊 Certificate information:${NC}"
openssl x509 -in "$SSL_CERT" -text -noout | grep -E "(Subject:|DNS:|IP Address:|Not Before|Not After)"
echo ""

echo -e "${YELLOW}💡 Next steps:${NC}"
echo "1. Start your Sinatra application: ruby app.rb"
echo "2. Start nginx: ./scripts/start-nginx.sh"
echo "3. Visit: https://localhost"
echo ""
echo -e "${YELLOW}⚠️  Note: Your browser will show a security warning for self-signed certificates.${NC}"
echo "This is normal for local development. Click 'Advanced' -> 'Proceed to localhost'."