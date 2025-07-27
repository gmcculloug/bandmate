require 'sinatra/activerecord/rake'
require 'rake'

# Load the application
require_relative 'app'

namespace :db do
  desc "Create a new migration"
  task :create_migration => :environment do
    name = ENV['NAME']
    if name.nil?
      puts "Usage: rake db:create_migration NAME=name_of_migration"
      puts "Example: rake db:create_migration NAME=add_user_preferences"
      exit 1
    end
    
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    filename = "#{timestamp}_#{name}.rb"
    filepath = File.join("db", "migrate", filename)
    
    # Create migrations directory if it doesn't exist
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Create migration file
    File.open(filepath, 'w') do |f|
      f.write <<~MIGRATION
        class #{name.camelize} < ActiveRecord::Migration[7.0]
          def change
            # Add your migration code here
          end
        end
      MIGRATION
    end
    
    puts "Created migration: #{filepath}"
  end

  desc "Run all pending migrations"
  task :migrate => :environment do
    # Create schema_migrations table if it doesn't exist
    unless ActiveRecord::Base.connection.table_exists?('schema_migrations')
      ActiveRecord::Base.connection.create_table :schema_migrations do |t|
        t.string :version, null: false
      end
      ActiveRecord::Base.connection.add_index :schema_migrations, :version, unique: true
    end
    
    # Get all migration files
    migration_files = Dir.glob(File.join("db", "migrate", "*.rb")).sort
    applied_versions = ActiveRecord::Base.connection.select_values("SELECT version FROM schema_migrations")
    
    pending_migrations = migration_files.select do |file|
      version = File.basename(file).split('_').first
      !applied_versions.include?(version)
    end
    
    if pending_migrations.empty?
      puts "No pending migrations."
      next
    end
    
    pending_migrations.each do |file|
      version = File.basename(file).split('_').first
      migration_name = File.basename(file, '.rb').split('_', 2).last.camelize
      
      puts "Running migration #{version}: #{migration_name}"
      
      # Load and run the migration
      load file
      migration_class = Object.const_get(migration_name)
      migration = migration_class.new
      migration.up
      
      # Record the migration as applied
      ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations (version) VALUES ('#{version}')")
    end
    
    puts "Migrations completed successfully!"
  end

  desc "Rollback the last migration"
  task :rollback => :environment do
    # Get the last applied migration
    last_version = ActiveRecord::Base.connection.select_value("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1")
    
    if last_version.nil?
      puts "No migrations to rollback."
      return
    end
    
    # Find the migration file
    migration_file = Dir.glob(File.join("db", "migrate", "#{last_version}_*.rb")).first
    
    if migration_file.nil?
      puts "Migration file not found for version #{last_version}"
      return
    end
    
    migration_name = File.basename(migration_file, '.rb').split('_', 2).last.camelize
    
    puts "Rolling back migration #{last_version}: #{migration_name}"
    
    # Load and run the migration down
    load migration_file
    migration_class = Object.const_get(migration_name)
    migration = migration_class.new
    migration.down
    
    # Remove the migration record
    ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations WHERE version = '#{last_version}'")
    
    puts "Rollback completed!"
  end

  desc "Show migration status"
  task :status => :environment do
    # Create schema_migrations table if it doesn't exist
    unless ActiveRecord::Base.connection.table_exists?('schema_migrations')
      ActiveRecord::Base.connection.create_table :schema_migrations do |t|
        t.string :version, null: false
      end
      ActiveRecord::Base.connection.add_index :schema_migrations, :version, unique: true
    end
    
    migration_files = Dir.glob(File.join("db", "migrate", "*.rb")).sort
    applied_versions = ActiveRecord::Base.connection.select_values("SELECT version FROM schema_migrations")
    
    puts "Database: #{ActiveRecord::Base.connection_db_config.configuration_hash[:database]}"
    puts "Status   Migration ID    Migration Name"
    puts "--------------------------------------------------"
    
    migration_files.each do |file|
      version = File.basename(file).split('_').first
      migration_name = File.basename(file, '.rb').split('_', 2).last.camelize
      status = applied_versions.include?(version) ? "up" : "down"
      puts "#{status.ljust(7)} #{version.ljust(14)} #{migration_name}"
    end
  end

  desc "Reset database (drop, create, migrate)"
  task :reset => :environment do
    puts "Dropping all tables..."
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
    
    puts "Running migrations..."
    Rake::Task['db:migrate'].invoke
    
    puts "Database reset completed!"
  end

  desc "Seed the database with initial data"
  task :seed => :environment do
    # Create a default band if none exists
    if Band.count == 0
      Band.create!(name: "My Band", notes: "Default band created during setup")
      puts "Created default band 'My Band'"
    else
      puts "Default band already exists"
    end
  end

  desc "Setup database (migrate + seed)"
  task :setup => :environment do
    puts "Running migrations..."
    Rake::Task['db:migrate'].invoke
    
    puts "Seeding database..."
    Rake::Task['db:seed'].invoke
    
    puts "Database setup completed!"
  end
end

# Helper method for camelizing strings
class String
  def camelize
    self.split('_').map(&:capitalize).join
  end
end 