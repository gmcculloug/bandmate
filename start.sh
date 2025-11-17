#!/bin/bash

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.4 or higher."
    exit 1
fi

# Start the application
echo "🚀 Starting the application..."
echo ""
ruby app.rb 