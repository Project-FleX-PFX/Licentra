require_relative '../models/user'

User.create(username: 'admin', password_digest: 'hashed_password_here')
