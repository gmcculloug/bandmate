#!/bin/bash

echo "🎸 Starting Bandmate - Song Management System"
echo ""

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.1 or higher."
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

# Start the application
echo "🚀 Starting the application..."
echo ""
ruby app.rb 
