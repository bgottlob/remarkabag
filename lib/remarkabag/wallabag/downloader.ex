defmodule Remarkabag.Wallabag.Downloader do
  use Task
  require Logger
  alias Remarkabag.{Entry, Wallabag}

  def child_spec([]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link() do
    Logger.info("Starting Wallabag entry downloader")
    Task.start_link(__MODULE__, :loop, [])
  end

  @sleep 6 * 1000
  def loop() do
    oauth_client = Wallabag.oauth_client()

    Enum.each(
      Entry.need_to_download(),
      fn entry ->
        path = download_path(entry.title)

        if File.exists?(path) do
          Logger.debug("#{path} already exists, not attempting to download #{entry.url}")
          Entry.write_downloaded(entry.id, path)
        else
          download_entry(oauth_client, entry)
        end
      end
    )

    Process.sleep(@sleep)
    loop()
  end

  @directory "#{System.user_home()}/.cache/remarkabag"
  defp download_path(title) do
    File.mkdir_p!(@directory)
    "#{@directory}/#{String.replace(title, "/", "_")}.epub"
  end

  defp download_entry(oauth_client, entry) do
    path = download_path(entry.title)

    try do
      content = export_epub(oauth_client, entry)
      File.write!(path, content)
      Logger.debug("Wrote exported content to #{path}")
      Entry.write_downloaded(entry.id, path)
    rescue
      e ->
        # TODO write the actual error
        Entry.write_download_error(entry.id)
        Logger.error("Entry `#{entry.title}` caused error\n\t#{e}")
    end
  end

  defp export_epub(oauth_client, entry) do
    token =
      oauth_client
      |> Map.fetch!(:token)
      |> Map.fetch!(:access_token)

    Logger.debug("Calling /api/entries/{id}/export")

    {_request, response} =
      Req.new(
        url:
          "#{Application.get_env(:remarkabag, :wallabag_url)}/api/entries/#{entry.wallabag_id}/export.epub"
      )
      |> Req.Request.put_header("authorization", "Bearer #{token}")
      |> Req.Request.put_header("accept", "*/*")
      |> Req.Request.merge_options(http_errors: :raise)
      |> Req.Request.run_request()

    # TODO verify epub binary is sent back with proper response headers
    Map.fetch!(response, :body)
  end
end
