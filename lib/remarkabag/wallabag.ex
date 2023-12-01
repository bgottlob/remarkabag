defmodule Remarkabag.Wallabag do
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
    Logger.info("Starting Wallabag syncer")
    Task.start_link(__MODULE__, :loop, [])
  end

  # 15 minutes between runs
  @sleep 15 * 60 * 1000
  def loop() do
    oauth_client() |> all_entries()
    Process.sleep(@sleep)
    loop()
  end

  def oauth_client() do
    client =
      OAuth2.Client.new(
        strategy: OAuth2.Strategy.Password,
        client_id: Application.get_env(:remarkabag, :wallabag_client_id),
        client_secret: Application.get_env(:remarkabag, :wallabag_client_secret),
        token_url: "#{Application.get_env(:remarkabag, :wallabag_url)}/oauth/v2/token"
      )
      |> OAuth2.Client.put_serializer("application/json", Jason)

    {:ok, client} =
      OAuth2.Client.get_token(
        client,
        username: Application.get_env(:remarkabag, :wallabag_username),
        password: Application.get_env(:remarkabag, :wallabag_password)
      )

    client
  end

  # archived: 0 picks up all entries, archived: 1 picks up only archived entries
  # There is no way through the API to only return non-archived entries
  @entries_defaults [detail: "metadata", page: 1, archived: 0]
  defp entries_options(options), do: Keyword.merge(@entries_defaults, options)

  # Syncs any new entries in Wallabag to Entry Mnesia table
  def entries(oauth_client, options \\ []) do
    token =
      oauth_client
      |> Map.fetch!(:token)
      |> Map.fetch!(:access_token)

    options = entries_options(options)

    IO.debug("Calling /api/entries page #{options[:page]}")

    {_request, response} =
      Req.new(url: "#{Application.get_env(:remarkabag, :wallabag_url)}/api/entries")
      |> Req.Request.put_header("authorization", "Bearer #{token}")
      |> Req.Request.merge_options(params: options)
      |> Req.Request.merge_options(http_errors: :raise)
      |> Req.Request.run_request()

    # Only consider non-archived entries
    entries =
      for item <- response.body["_embedded"]["items"], item["is_archived"] == 0 do
        %{
          "given_url" => url,
          "hashed_given_url" => url_hash,
          "id" => id,
          "title" => title,
          "mimetype" => mimetype
        } = item

        case Entry.by_url_hash(url_hash) do
          [] ->
            Entry.write_from_wallabag(id, mimetype, title, url, url_hash)

          _ ->
            Logger.debug("Found record with #{url_hash} in Entry table already")
        end
      end

    {entries, options[:page], response.body["pages"]}
  end

  def all_entries(oauth_client, options \\ []) do
    options = entries_options(options)
    all_entries(oauth_client, options, [], 1, nil)
  end

  defp all_entries(oauth_client, options, entries, page, pages)
       when page == nil or page <= pages do
    {curr_entries, page, pages} = entries(oauth_client, Keyword.merge(options, page: page))
    all_entries(oauth_client, options, [curr_entries | entries], page + 1, pages)
  end

  defp all_entries(_oauth_client, _options, entries, _page, _pages) do
    entries
    |> Enum.reverse()
    |> List.flatten()
  end
end
