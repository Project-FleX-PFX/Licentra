class Role < Sequel::Model
    many_to_many :users, join_table: :user_roles, left_key: :role_id, right_key: :user_id
  
    def validate
      super
      validates_presence :role_name
      validates_unique :role_name
    end
end
