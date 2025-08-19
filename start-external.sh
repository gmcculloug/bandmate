#!/bin/bash

echo "🎸 Starting Band-age with external access..."
echo ""

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 2.7 or higher."
    exit 1
fi

# Check if Bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "❌ Bundler is not installed. Installing..."
    gem install bundler
fi

# Install dependencies
echo "📦 Installing dependencies..."
bundle install

# Get local IP address
echo "🌐 Getting your local IP address..."
local_ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

if [ -z "$local_ip" ]; then
    echo "⚠️  Could not determine local IP address"
    echo "   You can still access the app via localhost:4567"
else
    echo "✅ Your local IP address is: $local_ip"
    echo "🌐 External access URL: http://$local_ip:4567"
fi

echo ""
echo "🚀 Starting the application..."
echo "   Local access: http://localhost:4567"
echo "   External access: http://$local_ip:4567"
echo ""
echo "📱 Other devices on your network can access the app using the external URL"
echo "🔒 Make sure your firewall allows connections on port 4567"
echo ""

# Start the application
BANDMATE_ACCT_CREATION_SECRET=1234 ruby app.rb 
