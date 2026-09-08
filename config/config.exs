import Config

config :ash, default_string_length_count: :codepoints

if config_env() == :test do
  config :logger, level: :warning
end
