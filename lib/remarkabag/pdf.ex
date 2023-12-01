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
    Logger.info "Starting PDF downloader"
    Task.start_link(__MODULE__, :download_loop, [])
  end

  # 5 minutes between runs
  @sleep 5 * 60 * 1000
  def download_loop() do
    entries = Entry.need_to_download()
    IO.inspect("Downloading #{length(entries)} entries")
    Enum.each(entries, fn entry ->
      id = Entry.id(entry)
      title = Entry.title(entry)
      url = Entry.url(entry)
      path = download_path(title)

      if File.exists?(path) do
        Logger.debug "#{path} already exists, not attempting to download #{url}"
        Entry.write_downloaded(id, path)
      else
        download_entry(id, title, url)
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
      Entry.write_downloaded(id, file_path) |> IO.inspect
    rescue
      e ->
        # TODO write the actual error
        Entry.write_download_error(id)
        Logger.error("URL `#{url}` caused error")
        # TODO change this to a debug log
        IO.inspect(e)
    end
  end
end
