# frozen_string_literal: true

Fabricator(:license_assignment) do
  license
  transient assign_to_user: true

  after_build do |assignment, transients|
    if transients[:assign_to_user]
      assignment.user = Fabricate(:user)
    else
      assignment.device = Fabricate(:device)
    end
  end

  assignment_date { Time.now }
  is_active true
end
