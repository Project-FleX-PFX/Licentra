# frozen_string_literal: true

require_relative '../../dao/errors'
require_relative '../../dao/logger'
require_relative '../../dao/error_handling'
require_relative '../../dao/base_dao'
require_relative '../../dao/concerns/crud_operations'

def require_models
  Dir[File.expand_path('../../models/**/*.rb', __dir__)].sort.each { |f| require f }
end

def require_daos
  dao_files = Dir[File.expand_path('../../dao/**/*.rb', __dir__)]

  # Load logging and error handling first
  dao_files.sort_by! do |f|
    [f.include?('logging') || f.include?('error_handling') ? 0 : 1, f]
  end

  dao_files.each do |f|
    next if f.end_with?('concerns/crud_operations.rb') || f.end_with?('base_dao.rb')

    require f
  end
end

require_models
require_daos
