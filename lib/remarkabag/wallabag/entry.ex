defmodule Remarkabag.Wallabag.Entry do
  defstruct [
    :id,
    :local_path,
    :mimetype,
    :title,
    :url,
    :url_hash
  ]
end
