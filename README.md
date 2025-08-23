# 🎸 Bandmate - Band Management System

A Sinatra-based web application for managing bands, songs, set lists, and venues.

## 🚀 Quick Start

### Prerequisites
- Ruby 2.7 or higher
- Bundler

### Installation
1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

### Database Setup
The application now uses proper database migrations instead of a full database reset.

#### First Time Setup
```bash
rake db:setup
```
This will:
- Run all pending migrations
- Seed the database with initial data (default band)

#### Alternative Setup (Legacy)
You can still use the web interface at `http://localhost:4567/setup` for first-time setup.

### Environment Variables
The application requires certain environment variables to be set for security and functionality:

- **SESSION_SECRET**: A secure random string for session encryption (at least 64 characters)
- **BANDMATE_ACCT_CREATION_SECRET**: An account creation code required for new user registration

You can set these in several ways:
1. Create a `.env` file in the project root (copy from `env.example`)
2. Export them in your shell: `export BANDMATE_ACCT_CREATION_SECRET=your_account_creation_code`
3. Set them when running the app: `BANDMATE_ACCT_CREATION_SECRET=your_account_creation_code ruby app.rb`

### Running the Application
```bash
ruby app.rb
```
Then visit `http://localhost:4567`

## 🗄️ Database Management

### Migration Commands

#### Create a new migration
```bash
rake db:create_migration[name_of_migration]
```
Example: `rake db:create_migration[add_user_preferences]`

#### Run pending migrations
```bash
rake db:migrate
```

#### Rollback the last migration
```bash
rake db:rollback
```

#### Check migration status
```bash
rake db:status
```

#### Reset database (drop, create, migrate)
```bash
rake db:reset
```

#### Seed database with initial data
```bash
rake db:seed
```

### Migration Files
Migrations are stored in `db/migrate/` and follow the format:
```
YYYYMMDDHHMMSS_descriptive_name.rb
```

## 📁 Project Structure

```
bandmate/
├── app.rb                 # Main application file
├── Gemfile               # Dependencies
├── Rakefile              # Database tasks
├── config/
│   └── database.yml      # Database configuration
├── db/
│   └── migrate/          # Database migrations
├── views/                # ERB templates
└── README.md            # This file
```

## 🎯 Features

- **Band Management**: Create and manage multiple bands
- **Song Library**: Store songs with metadata (key, tempo, genre, etc.)
- **Set Lists**: Create and organize set lists for performances
- **Venue Management**: Track venues with contact information
- **Performance Scheduling**: Schedule performances with dates and times
- **Mobile Responsive**: Works great on mobile devices
- **Print Support**: Print-friendly set list views

## 🔧 Development

### Adding New Features
1. Create a migration for any database changes:
   ```bash
   rake db:create_migration[add_new_feature]
   ```
2. Edit the generated migration file in `db/migrate/`
3. Run the migration:
   ```bash
   rake db:migrate
   ```
4. Update models and views as needed

### Database Schema Changes
- Always use migrations for schema changes
- Never modify the database directly
- Test migrations on a copy of production data

## 🧪 Testing

The project includes a comprehensive test suite using RSpec and FactoryBot.

### Running Tests

```bash
# Run all tests
rake spec
# or
bundle exec rspec

# Run specific test categories
bundle exec rspec spec/models/     # Model tests
bundle exec rspec spec/requests/   # Request/Integration tests

# Run specific test file
bundle exec rspec spec/models/band_spec.rb

# Run with verbose output
bundle exec rspec --format documentation
```

### Test Coverage

**Model Tests**: Validations, associations, scopes, and business logic
**Request Tests**: CRUD operations, form handling, search/filtering, API endpoints
**Integration Tests**: Set list management, band associations, database setup

### Test Structure

```
spec/
├── spec_helper.rb          # RSpec configuration
├── factories.rb            # FactoryBot factories
├── models/                 # Model tests
└── requests/               # Request/Integration tests
```

### Adding New Tests

1. Create factories in `spec/factories.rb` for new models
2. Add model tests in `spec/models/`
3. Add request tests in `spec/requests/`
4. Use descriptive test names and test both success and error cases

## 🐛 Troubleshooting

### Migration Issues
If you encounter migration problems:
1. Check migration status: `rake db:status`
2. Rollback if needed: `rake db:rollback`
3. Reset if necessary: `rake db:reset` (⚠️ This will delete all data)

### Database Connection Issues
- Check database configuration in `config/database.yml`
- Verify PostgreSQL is running and accessible
- Ensure database credentials are correct

## 📝 License

This project is open source and available under the MIT License. 