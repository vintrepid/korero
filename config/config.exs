import Config

config :ash, default_string_length_count: :codepoints
config :tag_ash, ash_domains: [TagAsh.Domain]

if config_env() == :test do
  config :logger, level: :warning
end
