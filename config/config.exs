import Config

# This config file is evaluated at compile time, but we'll use runtime.exs
# for actual database configuration that depends on environment variables

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end

if File.exists?("config/runtime.exs") do
  import_config "runtime.exs"
end
