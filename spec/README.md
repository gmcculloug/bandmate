# Bandmate Test Suite

This directory contains comprehensive tests for the Bandmate application, a Sinatra-based band management system.

## Test Structure

```
spec/
├── spec_helper.rb          # RSpec configuration and setup
├── factories.rb            # FactoryBot factories for test data
├── models/                 # Model tests
│   ├── band_spec.rb
│   ├── song_spec.rb
│   ├── venue_spec.rb
│   ├── set_list_spec.rb
│   └── set_list_song_spec.rb
├── requests/               # Request/Integration tests
│   ├── bands_spec.rb
│   ├── songs_spec.rb
│   ├── set_lists_spec.rb
│   ├── venues_spec.rb
│   └── api_spec.rb
└── README.md              # This file
```

## Running Tests

### Prerequisites

First, install the testing dependencies:

```bash
bundle install
```

### Running All Tests

```bash
# Using Rake (recommended)
rake test

# Or using RSpec directly
bundle exec rspec

# Or run specific test files
bundle exec rspec spec/models/band_spec.rb
```

### Running Specific Test Categories

```bash
# Run only model tests
bundle exec rspec spec/models/

# Run only request tests
bundle exec rspec spec/requests/

# Run tests for a specific model
bundle exec rspec spec/models/band_spec.rb

# Run tests for a specific feature
bundle exec rspec spec/requests/songs_spec.rb
```

### Test Options

```bash
# Run tests with verbose output
bundle exec rspec --format documentation

# Run tests with color output
bundle exec rspec --color

# Run tests and stop on first failure
bundle exec rspec --fail-fast

# Run tests with coverage (if simplecov is installed)
COVERAGE=true bundle exec rspec
```

## Test Coverage

### Model Tests

The model tests cover:

- **Validations**: All required fields, uniqueness constraints, and data type validations
- **Associations**: Has_many, belongs_to, and has_and_belongs_to_many relationships
- **Scopes**: Default ordering and filtering
- **Business Logic**: Custom methods and edge cases
- **Data Integrity**: Cascade deletions and constraint handling

### Request Tests

The request tests cover:

- **CRUD Operations**: Create, Read, Update, Delete for all resources
- **Form Handling**: Form display, validation, and error handling
- **Search and Filtering**: Song search by title/artist, band filtering
- **API Endpoints**: JSON responses and parameter handling
- **Edge Cases**: 404 errors, invalid data, duplicate entries
- **User Experience**: Redirects, flash messages, and proper routing

### Integration Tests

The integration tests cover:

- **Set List Management**: Adding/removing songs, reordering, copying
- **Band Associations**: Multi-band song relationships
- **Database Setup**: Initialization and seeding
- **API Functionality**: JSON endpoints for AJAX requests

## Test Data

Tests use FactoryBot factories to generate realistic test data:

- **Bands**: With names and notes
- **Songs**: With titles, artists, keys, tempos, and band associations
- **Venues**: With names, locations, contact info
- **Set Lists**: With bands, venues, dates, and times
- **Set List Songs**: With proper positioning

## Database Testing

- Tests use a separate SQLite test database (`bandmate_test.db`)
- Database is cleaned between tests using DatabaseCleaner
- Migrations are automatically run for the test environment
- Test database is cleaned up after all tests complete

## Continuous Integration

The test suite is designed to run in CI environments:

- No external dependencies (uses SQLite)
- Fast execution (under 30 seconds for full suite)
- Clear error messages and failure reporting
- Exit codes suitable for CI systems

## Adding New Tests

### For New Models

1. Create a factory in `spec/factories.rb`
2. Create model tests in `spec/models/`
3. Create request tests in `spec/requests/`

### For New Features

1. Add request tests for new routes
2. Add model tests for new business logic
3. Update factories if new data is needed

### Test Guidelines

- Use descriptive test names that explain the behavior
- Test both happy path and error cases
- Use factories for test data generation
- Keep tests focused and independent
- Use appropriate assertions for the type of test

## Troubleshooting

### Common Issues

**Database errors**: Ensure migrations are up to date
```bash
rake db:migrate RAILS_ENV=test
```

**Missing gems**: Install test dependencies
```bash
bundle install
```

**Slow tests**: Check for database cleanup issues
```bash
rm bandmate_test.db  # Remove test database
bundle exec rspec    # Recreate and run tests
```

### Debugging Tests

```bash
# Run a single test with debug output
bundle exec rspec spec/models/band_spec.rb:15 --format documentation

# Run tests with pry debugging
bundle exec rspec --require pry
```

## Performance

- Full test suite runs in ~20-30 seconds
- Individual test files run in 1-5 seconds
- Database operations are optimized with proper indexing
- Factory data is minimal but realistic

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure all existing tests pass
3. Add tests for edge cases and error conditions
4. Update this README if adding new test categories 