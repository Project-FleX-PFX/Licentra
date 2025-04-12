require_relative '../config/environment.rb'
require 'date'
require 'bcrypt'

puts "Seeding database..."

DB.transaction(rollback: :reraise) do

  puts "Deleting existing data..."
  AssignmentLog.dataset.delete
  LicenseAssignment.dataset.delete
  License.dataset.delete
  UserRole.dataset.delete
  UserCredential.dataset.delete
  User.dataset.delete
  Role.dataset.delete
  Device.dataset.delete
  LicenseType.dataset.delete
  Product.dataset.delete

  puts "Creating Products..."
  p_editor = Product.create(product_name: 'PowerEdit Pro')
  p_suite = Product.create(product_name: 'Office Suite Deluxe')
  p_cad = Product.create(product_name: 'CAD Master 3D')
  p_db = Product.create(product_name: 'DataCruncher DB')

  puts "Creating License Types..."
  lt_perp_user = LicenseType.create(type_name: 'Perpetual User', description: 'Einmaliger Kauf pro Benutzer.')
  lt_sub_user = LicenseType.create(type_name: 'Subscription User', description: 'Abonnement pro Benutzer.')
  lt_vol_user = LicenseType.create(type_name: 'Volume Subscription User', description: 'Abonnement für mehrere Benutzer (pro Platz).')
  lt_dev = LicenseType.create(type_name: 'Device License', description: 'Lizenz ist an ein Gerät gebunden.')
  lt_conc = LicenseType.create(type_name: 'Concurrent Usage', description: 'Maximale Anzahl gleichzeitiger Nutzer.')

  puts "Creating Roles..."
  r_admin = Role.create(role_name: 'Admin')
  r_manager = Role.create(role_name: 'LicenseManager')
  r_user = Role.create(role_name: 'User')

  puts "Creating Devices..."
  dev_ws01 = Device.create(device_name: 'Workstation-Dev-01', serial_number: 'WKSDEV01XYZ', notes: 'Dev Team Workstation')
  dev_lap05 = Device.create(device_name: 'Laptop-Sales-05', serial_number: 'LAPSAL05ABC', notes: 'Sales Team Laptop')
  dev_kiosk = Device.create(device_name: 'Reception Kiosk', notes: 'Shared device in reception')

  puts "Creating Users & Credentials..."
  admin = User.new(username: 'admin', email: 'admin@company.local', first_name: 'Admin', last_name: 'Istrator', is_active: true, credential_attributes: { password_plain: 'secureAdminPass123!' })
  admin.save

  manager = User.new(username: 'lic_manager', email: 'manager@company.local', first_name: 'Lisa', last_name: 'Manager', is_active: true, credential_attributes: { password_plain: 'manageMyLicenses!' })
  manager.save

  alice = User.new(username: 'alice', email: 'alice@company.local', first_name: 'Alice', last_name: 'Dev', is_active: true, credential_attributes: { password_plain: 'alicePassw0rd' })
  alice.save

  bob = User.new(username: 'bob', email: 'bob@company.local', first_name: 'Bob', last_name: 'Sales', is_active: true, credential_attributes: { password_plain: 'bobLikesSales1' })
  bob.save

  inactive_user = User.new(username: 'inactive', email: 'inactive@company.local', first_name: 'Inactive', last_name: 'User', is_active: false, credential_attributes: { password_plain: 'tempPass' })
  inactive_user.save

  puts "Assigning Roles..."
  admin.add_role(r_admin)
  admin.add_role(r_user)
  manager.add_role(r_manager)
  manager.add_role(r_user)
  alice.add_role(r_user)
  bob.add_role(r_user)
  inactive_user.add_role(r_user)

  puts "Creating Licenses..."
  today = Date.today
  lic_editor_single = License.create(
    product: p_editor,
    license_type: lt_sub_user,
    license_key: 'PEP-SUB-USER-A1B2',
    license_name: 'PowerEdit Pro User Subscription',
    seat_count: 1,
    purchase_date: today - 180,
    expire_date: today + 185,
    cost: 79.99, currency: 'EUR', vendor: 'EditorSoft', status: 'Active'
  )

  lic_suite_volume = License.create(
    product: p_suite,
    license_type: lt_vol_user,
    license_key: 'OSD-VOL-USER-C3D4-10PACK',
    license_name: 'Office Suite 10 User Pack Subscription',
    seat_count: 10,
    purchase_date: today - 30,
    expire_date: today + 335,
    cost: 899.00, currency: 'EUR', vendor: 'Office Corp.', status: 'Active'
  )

  lic_cad_device = License.create(
    product: p_cad,
    license_type: lt_dev,
    license_key: 'CADM-DEV-E5F6',
    license_name: 'CAD Master Device License',
    seat_count: 1,
    purchase_date: today - 400,
    expire_date: today + 300,
    cost: 2500.00, currency: 'USD', vendor: 'CAD Solutions', status: 'Active'
  )

  lic_db_perpetual = License.create(
    product: p_db,
    license_type: lt_perp_user,
    license_key: 'DCR-PERP-USER-G7H8',
    license_name: 'DataCruncher DB Perpetual User',
    seat_count: 1,
    purchase_date: today - 730,
    expire_date: nil,
    cost: 999.00, currency: 'USD', vendor: 'Data Inc.', status: 'Active'
  )

  lic_suite_expired = License.create(
    product: p_suite,
    license_type: lt_sub_user,
    license_key: 'OSD-SUB-USER-I9J0-EXPIRED',
    license_name: 'Expired Office Suite User Subscription',
    seat_count: 1,
    purchase_date: today - 400,
    expire_date: today - 35,
    cost: 99.00, currency: 'EUR', vendor: 'Office Corp.', status: 'Expired'
  )

  puts "Creating License Assignments..."
  ass_alice_editor = LicenseAssignment.create(
    license: lic_editor_single,
    user: alice,
    assignment_date: Time.now - 60*60*24*30,
    is_active: true
  )

  ass_bob_suite = LicenseAssignment.create(
    license: lic_suite_volume,
    user: bob,
    assignment_date: Time.now - 60*60*24*10,
    is_active: true
  )

  ass_manager_suite = LicenseAssignment.create(
    license: lic_suite_volume,
    user: manager,
    assignment_date: Time.now - 60*60*24*10,
    is_active: true
  )

  ass_inactive_suite = LicenseAssignment.create(
    license: lic_suite_volume,
    user: inactive_user,
    assignment_date: Time.now - 60*60*24*5,
    is_active: true,
    notes: "Assigned to currently inactive user"
  )

  ass_dev_cad = LicenseAssignment.create(
    license: lic_cad_device,
    device: dev_ws01,
    assignment_date: Time.now - 60*60*24*90,
    is_active: true,
    notes: 'Primary CAD license for Dev Workstation 01'
  )

  ass_bob_db = LicenseAssignment.create(
    license: lic_db_perpetual,
    user: bob,
    assignment_date: Time.now - 60*60*24*365,
    is_active: true
  )

  ass_alice_suite_expired = LicenseAssignment.create(
     license: lic_suite_expired,
     user: alice,
     assignment_date: Time.now - 60*60*24*200,
     is_active: false,
     notes: 'Assignment related to an expired license'
  )

   AssignmentLog.create(
       assignment_id: ass_alice_suite_expired.assignment_id,
       action: 'DEACTIVATED',
       details: 'Assignment deactivated manually or due to license expiry.',
       log_timestamp: (lic_suite_expired.expire_date + 1).to_time
   )

   temp_ass = LicenseAssignment.create(
       license: lic_suite_volume,
       user: alice,
       assignment_date: Time.now - 60*60*24*2,
       is_active: true,
       notes: 'Temporary assignment for Alice'
   )
   puts "Deactivating temporary assignment for Alice (ID: #{temp_ass.assignment_id})..."
   temp_ass.update(is_active: false, notes: 'Deactivated shortly after creation for testing.')

  puts "Seeding finished successfully."

end