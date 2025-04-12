class UserRole < Sequel::Model(:user_roles)
    many_to_one :user, key: :user_id
    many_to_one :role, key: :role_id
end
