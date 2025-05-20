# frozen_string_literal: true

require 'bcrypt'

# Represents a user in the system who can be assigned licenses
# Contains user identification and profile information
class User < Sequel::Model
  plugin :nested_attributes
  one_to_one :credential, class: 'UserCredential', key: :user_id
  plugin :association_dependencies, credential: :delete
  nested_attributes :credential, destroy: true
  one_to_many :license_assignments, key: :user_id
  many_to_many :roles, join_table: :user_roles, left_key: :user_id, right_key: :role_id

  def authenticate(plain_password)
    credential&.authenticate(plain_password)
  end

  def role?(role_name)
    role_name_to_check = role_name.to_s
    DB[:user_roles].join(:roles, role_id: :role_id)
                   .where(user_id: pk, Sequel.qualify(:roles, :role_name) => role_name_to_check)
                   .count.positive?
  end

  def admin?
    role?('Admin')
  end

  def validate
    super
    validates_presence [:username]
    validates_unique :username
    validates_unique :email, allow_nil: true
    validates_format(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/, :email, allow_nil: true, message: 'is not a valid email address')
  end
end
