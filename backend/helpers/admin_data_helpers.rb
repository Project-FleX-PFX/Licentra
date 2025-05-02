# frozen_string_literal: true

# Helper for Admin Data View
module AdminDataHelpers
  def load_all_data
    @products = ProductDAO.all
    @license_types = LicenseTypeDAO.all
    @roles = RoleDAO.all
    @users = UserDAO.all
    @devices = DeviceDAO.all
    @licenses = LicenseDAO.all
    @assignments = LicenseAssignmentDAO.all
    @logs = AssignmentLogDAO.all
  end
end
