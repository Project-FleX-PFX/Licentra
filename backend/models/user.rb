class User < Sequel::Model
  plugin :timestamps, update_on_create: true
  
  def validate
    super
    errors.add(:username, 'cannot be empty') if !username || username.empty?
    errors.add(:password_digest, 'cannot be empty') if !password_digest || password_digest.empty?
  end
end

