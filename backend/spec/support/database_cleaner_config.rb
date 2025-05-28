# frozen_string_literal: true

# support/database_cleaner_config.rb
RSpec.configure do |config|
  config.before(:suite) do
    DB.run 'PRAGMA foreign_keys = OFF' # Wichtig für SQLite bei :truncation
    DatabaseCleaner[:sequel].clean_with(:truncation)
    DB.run 'PRAGMA foreign_keys = ON'
  end

  config.around(:each) do |example| # Geändert zu around für bessere Kapselung
    DatabaseCleaner[:sequel].strategy = :transaction
    DatabaseCleaner[:sequel].cleaning do
      example.run
    end
  end
end
