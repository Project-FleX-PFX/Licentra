class AssignmentLog < Sequel::Model(:assignment_logs)
   self.plugin :timestamps, disabled: true
 
   many_to_one :license_assignment, key: :assignment_id
 
   def validate
     super
     validates_presence [:assignment_id, :log_timestamp, :action]
   end
end
