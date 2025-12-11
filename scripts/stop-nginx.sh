#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Stopping nginx...${NC}"

# Check if nginx is running
if pgrep nginx > /dev/null; then
    echo -e "${YELLOW}Stopping nginx processes...${NC}"
    nginx -s stop
    sleep 2

    # Force kill if still running
    if pgrep nginx > /dev/null; then
        echo -e "${YELLOW}Force stopping nginx...${NC}"
        pkill -f nginx
    fi

    echo -e "${GREEN}✅ nginx stopped successfully${NC}"
else
    echo -e "${YELLOW}⚠️  nginx is not running${NC}"
fi