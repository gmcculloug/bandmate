# Use Ruby 3.2 slim image as base
FROM ruby:3.2-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby gems
RUN bundle install

# Copy application code
COPY . .

# Run database migrations
RUN rake db:migrate

# Create directory for SQLite database
RUN mkdir -p /app/data

# Set environment variables
ENV RACK_ENV=production
ENV PORT=4567

# Expose port
EXPOSE 4567

# Create a non-root user for security
RUN useradd -m -u 1000 bandmate && \
    chown -R bandmate:bandmate /app
USER bandmate

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4567/ || exit 1

# Start the application
CMD ["ruby", "app.rb"] 