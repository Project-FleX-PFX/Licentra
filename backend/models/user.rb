class User < Sequel::Model(DB[:users])
  set_primary_key :user_id
  one_to_many :license_assignments, key: :user_id

  def validate
    super
    errors.add(:username, 'cannot be empty') if !username || username.empty?
    errors.add(:password_digest, 'cannot be empty') if !password_digest || password_digest.empty?
  end
end
