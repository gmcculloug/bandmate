# This file can be used to seed the database with initial data
# Example:
# Band.create!(name: "My Band", notes: "Default band created during setup")

# Create a default band if none exists
if Band.count == 0
  Band.create!(name: "My Band", notes: "Default band created during setup")
  puts "Created default band 'My Band'"
else
  puts "Default band already exists"
end 