RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"] || ENV["OPENAI_ACCESS_TOKEN"]

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
