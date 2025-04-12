raise "Database constant DB not found" unless defined?(DB)

require 'bcrypt'

puts "Deleting existing data..."
begin
  DB.run('TRUNCATE TABLE "license_uses", "license_assignments", "licenses", "users", "license_types", "products" RESTART IDENTITY CASCADE;')
rescue Sequel::DatabaseError => e
  puts "Truncate failed (maybe tables don't exist yet?): #{e.message}"
end

puts "Creating products..."
product1_id = DB[:products].insert(product_name: 'Software A')
product2_id = DB[:products].insert(product_name: 'Plugin B')
puts " -> Product IDs: #{product1_id}, #{product2_id}"

puts "Creating license types..."
type1_id = DB[:license_types].insert(variant: 'Single User', max_assignment: 1)
type2_id = DB[:license_types].insert(variant: 'Multi User', max_assignment: 5)
puts " -> License Type IDs: #{type1_id}, #{type2_id}"

puts "Creating users..."
hashed_pw_1 = BCrypt::Password.create('secret_password_for_alice')
hashed_pw_admin = BCrypt::Password.create('super_secret_admin_password')

user1_id = DB[:users].insert(username: 'alice', password: hashed_pw_1, is_admin: false)
user2_id = DB[:users].insert(username: 'admin', password: hashed_pw_admin, is_admin: true)
puts " -> User IDs: #{user1_id}, #{user2_id}"

puts "Creating licenses..."
license1_id = DB[:licenses].insert(product_id: product1_id, license_type_id: type1_id, license_key: 'ABC-123-S')
license2_id = DB[:licenses].insert(product_id: product2_id, license_type_id: type2_id, license_key: 'DEF-456-M')
puts " -> License IDs: #{license1_id}, #{license2_id}"

puts "Creating assignments..."
assignment1_id = DB[:license_assignments].insert(license_id: license1_id, user_id: user1_id)
assignment2_id = DB[:license_assignments].insert(license_id: license2_id, user_id: user1_id)
puts " -> Assignment IDs: #{assignment1_id}, #{assignment2_id}"

puts "Creating license uses..."
DB[:license_uses].insert(assignment_id: assignment1_id, usage_date: Sequel.function(:now))
sleep 1
DB[:license_uses].insert(assignment_id: assignment2_id, usage_date: Sequel.function(:now))
puts " -> License uses created."

puts "Seeding finished."
