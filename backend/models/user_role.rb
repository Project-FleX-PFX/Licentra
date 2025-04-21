# frozen_string_literal: true

# Represents the association between a user and a role
# Enables users to have multiple roles for fine-grained access control
class UserRole < Sequel::Model(:user_roles)
  many_to_one :user, key: :user_id
  many_to_one :role, key: :role_id
end
