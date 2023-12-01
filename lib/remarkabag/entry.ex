defmodule Remarkabag.Entry do
  require Logger
  alias :mnesia, as: Mnesia

  @attrs [
    :id,
    :downloaded_path,
    :mimetype,
    :remarkable_path,
    :title,
    :url,
    :url_hash,
    :wallabag_id
  ]

  defstruct @attrs

  def create_table() do
    # node = node()

    # case Mnesia.create_table(__MODULE__, attributes: @attrs, disc_copies: [node]) do
    case Mnesia.create_table(__MODULE__, attributes: @attrs) do
      {:atomic, :ok} ->
        Logger.info("Created Mnesia table `#{__MODULE__}`")

      {:aborted, {:already_exists, __MODULE__}} ->
        Logger.info("Mnesia table `#{__MODULE__}` already exists")
    end

    case Mnesia.add_table_index(__MODULE__, :downloaded_path) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, __MODULE__, _index}} ->
        :ok
    end

    case Mnesia.add_table_index(__MODULE__, :remarkable_path) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, __MODULE__, _index}} ->
        :ok
    end

    case Mnesia.add_table_index(__MODULE__, :url_hash) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, __MODULE__, _index}} ->
        :ok
    end

    case Mnesia.add_table_index(__MODULE__, :wallabag_id) do
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, __MODULE__, _index}} ->
        :ok
    end

    # case Mnesia.add_table_copy(__MODULE__, node, :disc_copy) do
    #  {:atomic, :ok} ->
    #    :ok

    #  {:aborted, {:already_exists, __MODULE__, ^node}} ->
    #    :ok
    # end
  end

  # Retrieves an entry given the url_hash
  def by_url_hash(url_hash) do
    {:atomic, records} =
      Mnesia.transaction(fn ->
        Mnesia.index_read(__MODULE__, url_hash, :url_hash)
      end)

    for record <- records, do: from_tuple(record)
  end

  # Convert a record from the Entry Mnesia table to an Entry struct
  def from_tuple({
        __MODULE__,
        id,
        downloaded_path,
        mimetype,
        remarkable_path,
        title,
        url,
        url_hash,
        wallabag_id
      }) do
    %__MODULE__{
      id: id,
      downloaded_path: downloaded_path,
      mimetype: mimetype,
      remarkable_path: remarkable_path,
      title: title,
      url: url,
      url_hash: url_hash,
      wallabag_id: wallabag_id
    }
  end

  defp from_list([
         __MODULE__,
         id,
         downloaded_path,
         mimetype,
         remarkable_path,
         title,
         url,
         url_hash,
         wallabag_id
       ]) do
    %__MODULE__{
      id: id,
      downloaded_path: downloaded_path,
      mimetype: mimetype,
      remarkable_path: remarkable_path,
      title: title,
      url: url,
      url_hash: url_hash,
      wallabag_id: wallabag_id
    }
  end

  # Reads on Mnesia
  def need_to_download() do
    {:atomic, records} =
      Mnesia.transaction(fn ->
        Mnesia.match_object({__MODULE__, :_, nil, :_, nil, :_, :_, :_, :_})
      end)

    for record <- records, do: from_tuple(record)
  end

  def need_to_remarkable_sync() do
    {:atomic, records} =
      Mnesia.transaction(fn ->
        Mnesia.select(
          __MODULE__,
          [
            {
              {:"$0", :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8"},
              # downloaded_path is a string, remarkable_path is nil
              [{:"=/=", :"$2", nil}, {:"=/=", :"$2", :error}, {:==, :"$4", nil}],
              [:"$$"]
            }
          ]
        )
      end)

    for record <- records, do: from_list(record)
  end

  def by_downloaded_path_and_synced(downloaded_path, synced) do
    downloaded_path_guard =
      case downloaded_path do
        true -> {:is_binary, :"$2"}
        false -> {:==, :"$2", nil}
      end

    Mnesia.transaction(fn ->
      Mnesia.select(
        __MODULE__,
        [
          {
            {__MODULE__, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", "$8"},
            [downloaded_path_guard, {:==, :"$4", synced}],
            [:"$$"]
          }
        ]
      )
    end)
  end

  # Writes on Mnesia
  def write_from_wallabag(wallabag_id, mimetype, title, url, url_hash) do
    entry = %__MODULE__{
      id: UUID.uuid4(),
      downloaded_path: nil,
      mimetype: mimetype,
      remarkable_path: nil,
      title: title,
      url: url,
      url_hash: url_hash,
      wallabag_id: wallabag_id
    }

    {:atomic, :ok} =
      Mnesia.transaction(fn ->
        Mnesia.write({
          __MODULE__,
          entry.id,
          entry.downloaded_path,
          entry.mimetype,
          entry.remarkable_path,
          entry.title,
          entry.url,
          entry.url_hash,
          entry.wallabag_id
        })
      end)
  end

  def write_downloaded(id, downloaded_path) do
    {:atomic, :ok} =
      Mnesia.transaction(fn ->
        [entry] = Mnesia.read(__MODULE__, id, :write)
        entry = put_elem(entry, 2, downloaded_path)
        Mnesia.write(entry)
      end)
  end

  def write_download_error(id) do
    {:atomic, :ok} =
      Mnesia.transaction(fn ->
        [entry] = Mnesia.read(__MODULE__, id, :write)
        entry = put_elem(entry, 2, :error)
        Mnesia.write(entry)
      end)
  end

  def write_remarkable_synced(id, remarkable_path) do
    {:atomic, :ok} =
      Mnesia.transaction(fn ->
        [entry] = Mnesia.read(__MODULE__, id, :write)
        entry = put_elem(entry, 4, remarkable_path)
        Mnesia.write(entry)
      end)
  end
end
