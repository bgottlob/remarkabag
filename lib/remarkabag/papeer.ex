defmodule Remarkabag.Papeer do
  alias Remarkabag.Wallabag.Entry

  @directory "/tmp/remarkabag/papeer"
  def download_entry(entry = %Entry{title: title, url: url}) do
    File.mkdir_p!(@directory)
    filename = "#{title}.epub"

    System.cmd(
      "papeer",
      ["get", "--format", "epub", "--output", filename, url],
      cd: @directory
    )

    Map.put(entry, :local_path, "#{@directory}/#{filename}")
  end
end
