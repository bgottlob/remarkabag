defmodule Remarkabag.Wallabag do
  alias Remarkabag.Wallabag.Entry

  def oauth_client do
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

  @entries_defaults [detail: "metadata", page: 1]
  defp entries_options(options), do: Keyword.merge(@entries_defaults, options)

  def entries(oauth_client, options \\ []) do
    token =
      oauth_client
      |> Map.fetch!(:token)
      |> Map.fetch!(:access_token)

    options = entries_options(options)

    IO.puts("Calling /api/entries page #{options[:page]}")

    {_request, response} =
      Req.new(url: "#{Application.get_env(:remarkabag, :wallabag_url)}/api/entries")
      |> Req.Request.put_header("authorization", "Bearer #{token}")
      |> Req.Request.merge_options(params: options)
      |> Req.Request.merge_options(http_errors: :raise)
      |> Req.Request.run_request()

    entries =
      for item <- response.body["_embedded"]["items"] do
        %{
          "given_url" => url,
          "hashed_given_url" => url_hash,
          "id" => id,
          "title" => title,
          "mimetype" => mimetype
        } = item

        struct!(Entry, %{
          id: id,
          mimetype: mimetype,
          title: title,
          url: url,
          url_hash: url_hash
        })
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
    all_entries(oauth_client, options, [curr_entries | entries], page + 1, pages |> IO.inspect())
  end

  defp all_entries(_oauth_client, _options, entries, _page, _pages) do
    entries
    |> Enum.reverse()
    |> List.flatten()
  end
end
