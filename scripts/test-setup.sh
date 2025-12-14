#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}🧪 Testing Band Huddle HTTPS setup${NC}"
echo ""

# Test 1: Check if SSL certificates exist
echo -e "${YELLOW}1. Checking SSL certificates...${NC}"
if [ -f "$PROJECT_ROOT/ssl/server.crt" ] && [ -f "$PROJECT_ROOT/ssl/server.key" ]; then
    echo -e "${GREEN}   ✅ SSL certificates found${NC}"

    # Check certificate validity
    if openssl x509 -checkend 86400 -noout -in "$PROJECT_ROOT/ssl/server.crt" &>/dev/null; then
        echo -e "${GREEN}   ✅ Certificate is valid${NC}"
    else
        echo -e "${RED}   ❌ Certificate expires within 24 hours${NC}"
        echo "   Run: ./scripts/generate-certs.sh"
    fi
else
    echo -e "${RED}   ❌ SSL certificates not found${NC}"
    echo "   Run: ./scripts/generate-certs.sh"
fi

# Test 2: Check nginx configuration
echo ""
echo -e "${YELLOW}2. Checking nginx configuration...${NC}"
if [ -f "$PROJECT_ROOT/config/nginx-local.conf" ]; then
    echo -e "${GREEN}   ✅ nginx configuration exists${NC}"

    if command -v nginx &> /dev/null; then
        if nginx -t -c "$PROJECT_ROOT/config/nginx-local.conf" &>/dev/null; then
            echo -e "${GREEN}   ✅ nginx configuration is valid${NC}"
        else
            echo -e "${RED}   ❌ nginx configuration has errors${NC}"
            echo "   Run: nginx -t -c $PROJECT_ROOT/config/nginx-local.conf"
        fi
    else
        echo -e "${YELLOW}   ⚠️  nginx not installed - cannot test configuration${NC}"
        echo "   Install with: brew install nginx"
    fi
else
    echo -e "${RED}   ❌ nginx configuration not found${NC}"
fi

# Test 3: Check if scripts exist and are executable
echo ""
echo -e "${YELLOW}3. Checking scripts...${NC}"
scripts=("start-nginx.sh" "stop-nginx.sh" "generate-certs.sh")

for script in "${scripts[@]}"; do
    if [ -x "$PROJECT_ROOT/scripts/$script" ]; then
        echo -e "${GREEN}   ✅ $script is executable${NC}"
    else
        echo -e "${RED}   ❌ $script is missing or not executable${NC}"
    fi
done

# Test 4: Check if Sinatra app can start
echo ""
echo -e "${YELLOW}4. Checking Sinatra application...${NC}"
if [ -f "$PROJECT_ROOT/app.rb" ]; then
    echo -e "${GREEN}   ✅ app.rb found${NC}"

    if command -v ruby &> /dev/null; then
        echo -e "${GREEN}   ✅ Ruby is installed${NC}"

        if command -v bundle &> /dev/null; then
            echo -e "${GREEN}   ✅ Bundler is available${NC}"

            # Check if we're in the right directory and gems are installed
            cd "$PROJECT_ROOT"
            if bundle check &>/dev/null; then
                echo -e "${GREEN}   ✅ Dependencies are installed${NC}"
            else
                echo -e "${YELLOW}   ⚠️  Dependencies need to be installed${NC}"
                echo "   Run: bundle install"
            fi
        else
            echo -e "${RED}   ❌ Bundler not installed${NC}"
            echo "   Install with: gem install bundler"
        fi
    else
        echo -e "${RED}   ❌ Ruby not found${NC}"
    fi
else
    echo -e "${RED}   ❌ app.rb not found${NC}"
fi

# Test 5: Check log directory
echo ""
echo -e "${YELLOW}5. Checking log directory...${NC}"
if [ -d "$PROJECT_ROOT/nginx/logs" ]; then
    echo -e "${GREEN}   ✅ Log directory exists${NC}"
else
    echo -e "${YELLOW}   ⚠️  Creating log directory...${NC}"
    mkdir -p "$PROJECT_ROOT/nginx/logs"
    echo -e "${GREEN}   ✅ Log directory created${NC}"
fi

echo ""
echo -e "${BLUE}📋 Setup Summary:${NC}"
echo ""
echo -e "${YELLOW}To start the complete HTTPS setup:${NC}"
echo "1. Ensure dependencies are installed:"
echo "   bundle install"
echo ""
echo "2. Start your Sinatra application:"
echo "   ruby app.rb"
echo ""
echo "3. In another terminal, start nginx:"
echo "   ./scripts/start-nginx.sh"
echo ""
echo "4. Visit your application:"
echo "   https://localhost"
echo "   https://band-huddle.local (requires hosts file entry)"
echo ""
echo -e "${YELLOW}To add band-huddle.local to your hosts file:${NC}"
echo "   echo '127.0.0.1 band-huddle.local' | sudo tee -a /etc/hosts"
echo ""
echo -e "${YELLOW}To stop nginx:${NC}"
echo "   ./scripts/stop-nginx.sh"