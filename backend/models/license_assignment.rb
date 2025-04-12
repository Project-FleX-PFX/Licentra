class LicenseAssignment < Sequel::Model(:license_assignments)
    plugin :dirty
    many_to_one :license, key: :license_id
    many_to_one :user, key: :user_id
    many_to_one :device, key: :device_id
    one_to_many :assignment_logs, key: :assignment_id
  
    def after_create
      super
      AssignmentLog.create(
        assignment_id: self.assignment_id,
        action: 'ASSIGNED',
        details: "Assigned to #{assignee_type} ID: #{assignee_id}",
        log_timestamp: Time.now
      )
    end
  
    def before_update
      if column_changed?(:is_active)
        action = self.is_active ? 'ACTIVATED' : 'DEACTIVATED'
        AssignmentLog.create(
          assignment_id: self.assignment_id,
          action: action,
          details: "Assignment status changed to #{self.is_active}",
          log_timestamp: Time.now
        )
      end
      super
    end
  
    def assignee
      user || device
    end
  
    def assignee_id
      user_id || device_id
    end
  
    def assignee_type
      user_id ? 'User' : 'Device'
    end
  
    def validate
      super
      validates_presence [:license_id, :assignment_date]
      errors.add(:base, 'Either user_id or device_id must be set, but not both') if user_id && device_id
      errors.add(:base, 'Either user_id or device_id must be set') unless user_id || device_id
  
      if license && license.available_seats <= 0 && is_active? && new?
          errors.add(:license_id, 'has no available seats')
      end
   end
end
