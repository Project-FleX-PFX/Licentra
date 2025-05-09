# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner[:sequel].clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner[:sequel].strategy = :transaction
    DatabaseCleaner[:sequel].start
  end

  config.after(:each) do
    DatabaseCleaner[:sequel].clean
  end
end
