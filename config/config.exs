import Config

# Configure logger - quieter by default
config :logger, level: :info

# Import environment specific config
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end

if File.exists?("config/runtime.exs") do
  import_config "runtime.exs"
end
