# 🎸 Bandage - Song Management System

A comprehensive Ruby web application for managing band songs and set lists. Built with Sinatra and SQLite, featuring a modern, responsive interface.

## Features

### Song Management
- ✅ Add, edit, and delete songs
- ✅ Associate songs with multiple bands
- ✅ Track key and original key information
- ✅ Store tempo (BPM) for each song
- ✅ Include streaming platform URLs (YouTube, Spotify, etc.)
- ✅ Additional song properties: genre, duration, year, album, notes
- ✅ Beautiful card-based song display

### Set List Management
- ✅ Create and manage multiple set lists
- ✅ Add songs to set lists with automatic ordering
- ✅ Remove songs from set lists
- ✅ Print-friendly set list views
- ✅ Set list summary with total duration
- ✅ Notes for each set list

### User Interface
- ✅ Modern, responsive design with gradient backgrounds
- ✅ Intuitive navigation
- ✅ Print-optimized set list layouts
- ✅ Mobile-friendly interface
- ✅ Real-time song management

## Quick Start

### Prerequisites
- Ruby 2.7 or higher
- Bundler gem

### Installation

1. **Clone or download the project**
   ```bash
   cd bandage
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup the database**
   ```bash
   ruby app.rb
   ```
   Then visit `http://localhost:4567/setup` in your browser to create the database tables and a default band.

4. **Start the application**
   ```bash
   ruby app.rb
   ```

5. **Open your browser**
   Navigate to `http://localhost:4567`

## Usage

### Adding Songs
1. **First, ensure you have at least one band created** - Songs must be associated with at least one band
2. Click "Add Song" from the navigation
3. Fill in the required fields:
   - **Bands**: Select one or more bands this song belongs to (hold Ctrl/Cmd to select multiple)
   - **Title**: Song name
   - **Artist**: Original artist
   - **Key**: Current key your band plays in
   - **Original Key**: Original key of the song - optional
   - **Tempo**: BPM (beats per minute) - optional
4. Optionally add:
   - Genre, duration, year, album
   - Streaming URL (YouTube, Spotify, etc.)
   - Notes (chords, lyrics, special instructions)
5. Click "Save Song"

### Creating Set Lists
1. **First, ensure you have a band created** - Set lists must be associated with a band
2. Click "Create Set List" from the navigation
3. Enter a name for your set list
4. Select the band this set list belongs to
5. Add optional notes (venue, date, etc.)
6. Click "Create Set List"
7. Add songs to your set list from the set list view

### Managing Set Lists
- **View**: See all songs in the set list with details
- **Edit**: Modify set list name and notes
- **Print**: Generate a print-friendly version
- **Add Songs**: Select from available songs
- **Remove Songs**: Remove songs from the set list

### Printing Set Lists
1. Navigate to any set list
2. Click the "Print" button
3. The print view will open in a new tab
4. Use your browser's print function (Ctrl+P / Cmd+P)

## File Structure

```
bandage/
├── app.rb              # Main Sinatra application
├── Gemfile             # Ruby dependencies
├── README.md           # This file
├── bandage.db          # SQLite database (created after setup)
└── views/              # ERB templates
    ├── layout.erb      # Main layout template
    ├── index.erb       # Home page
    ├── songs.erb       # Songs listing
    ├── new_song.erb    # Add song form
    ├── show_song.erb   # Song detail view
    ├── edit_song.erb   # Edit song form
    ├── set_lists.erb   # Set lists listing
    ├── new_set_list.erb # Create set list form
    ├── show_set_list.erb # Set list detail view
    ├── edit_set_list.erb # Edit set list form
    └── print_set_list.erb # Print-friendly set list
```

## Database Schema

### Songs Table
- `id` - Primary key
- `title` - Song title (required)
- `artist` - Artist name (required)
- `key` - Current key (required)
- `original_key` - Original key (optional)
- `tempo` - BPM (optional)
- `genre` - Song genre
- `url` - Streaming platform URL
- `notes` - Additional notes
- `duration` - Song duration (e.g., "3:45")
- `year` - Release year
- `album` - Album name
- `created_at`, `updated_at` - Timestamps

### Bands Songs Table (Join Table)
- `id` - Primary key
- `band_id` - Foreign key to bands
- `song_id` - Foreign key to songs
- `created_at`, `updated_at` - Timestamps

### Set Lists Table
- `id` - Primary key
- `name` - Set list name (required)
- `notes` - Set list notes
- `created_at`, `updated_at` - Timestamps

### Set List Songs Table (Join Table)
- `id` - Primary key
- `set_list_id` - Foreign key to set_lists
- `song_id` - Foreign key to songs
- `position` - Order in set list (required)
- `created_at`, `updated_at` - Timestamps

## Customization

### Adding New Song Properties
1. Add the column to the database schema in `app.rb` (setup route)
2. Update the Song model validations if needed
3. Add form fields to `new_song.erb` and `edit_song.erb`
4. Update display templates as needed

### Styling
The application uses CSS Grid and Flexbox for responsive design. Styles are included in `views/layout.erb` and can be customized there.

## Troubleshooting

### Database Issues
If you encounter database errors:
1. Delete the `bandage.db` file
2. Restart the application
3. Visit `http://localhost:4567/setup` to recreate the database

### Port Already in Use
If port 4567 is already in use, you can change it by modifying the last line in `app.rb`:
```ruby
set :port, 4569  # or any other available port
```

## Docker Deployment

### Quick Start with Docker
```bash
# Build and run with Docker Compose (recommended)
docker-compose up -d

# Or build and run manually
docker build -t bandage .
docker run -p 4567:4567 -v $(pwd)/data:/app/data bandage
```

### Docker Features
- **Persistent Database**: Database is stored in `./data` directory
- **Health Checks**: Automatic health monitoring
- **Security**: Runs as non-root user
- **Production Ready**: Optimized for production deployment

### Environment Variables
- `DATABASE_PATH`: Path to SQLite database file (default: `bandage.db`)
- `RACK_ENV`: Environment mode (default: `production`)
- `PORT`: Application port (default: `4567`)

### Database Setup
After starting the container, visit `http://localhost:4567/setup` to initialize the database and create a default band.

## Contributing

Feel free to fork this project and submit pull requests for improvements!

## License

This project is open source and available under the MIT License. 