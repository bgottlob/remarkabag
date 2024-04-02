import Config

config :remarkabag,
  # Wallabag API
  wallabag_client_id: System.get_env("WALLABAG_CLIENT_ID"),
  wallabag_client_secret: System.get_env("WALLABAG_CLIENT_SECRET"),
  wallabag_username: System.get_env("WALLABAG_USERNAME"),
  wallabag_password: System.get_env("WALLABAG_PASSWORD"),
  wallabag_url: System.get_env("WALLABAG_URL"),

  # Remarkable Cloud API
  remarkable_url: System.get_env("REMARKABLE_URL"),
  rmapi_config: System.get_env("RMAPI_CONFIG"),

  # Rmfakecloud API
  rmfakecloud_url: System.get_env("RMFAKECLOUD_URL"),
  rmfakecloud_username: System.get_env("RMFAKECLOUD_USERNAME"),
  rmfakecloud_password: System.get_env("RMFAKECLOUD_PASSWORD")
