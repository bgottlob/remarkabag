defmodule Remarkabag.PDF do
  use Task
  require Logger
  alias Remarkabag.Entry

  def child_spec([]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link() do
    Logger.info("Starting PDF downloader")
    Task.start_link(__MODULE__, :download_loop, [])
  end

  # 5 minutes between runs
  @sleep 1 * 6 * 1000
  def download_loop() do
    entries = Entry.need_to_download()
    Logger.info("Downloading #{length(entries)} entries")

    Enum.each(entries, fn entry ->
      if File.exists?(entry.path) do
        Logger.debug("#{entry.path} already exists, not attempting to download #{entry.url}")
        Entry.write_downloaded(entry.id, entry.path)
      else
        download_entry(entry.id, entry.title, entry.url)
      end
    end)

    Process.sleep(@sleep)
    download_loop()
  end

  @directory "#{System.user_home()}/.cache/remarkabag"
  defp download_path(title) do
    File.mkdir_p!(@directory)
    "#{@directory}/#{String.replace(title, "/", "_")}.pdf"
  end

  def download_entry(id, title, url) do
    file_path = download_path(title)

    try do
      ChromicPDF.print_to_pdf({:url, url}, output: file_path)
      Entry.write_downloaded(id, file_path)
    rescue
      _e ->
        # TODO write the actual error
        Entry.write_download_error(id)
    end
  end
end
