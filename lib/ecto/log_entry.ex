defmodule Ecto.LogEntry do
  @doc """
  Struct used for logging entries.

  It is composed of the following fields:

    * query - the query as string or a function that when invoked
      resolves to string;
    * params - the query parameters;
    * result - the query result as an `:ok` or `:error` tuple;
    * query_time - the time spent executing the query in microseconds;
    * decode_time - the time spent decoding the result in microseconds (it may be nil);
    * queue_time - the time spent to check the connection out in microseconds (it may be nil);
    * connection_pid - the connection process that executed the query
  """

  alias Ecto.LogEntry

  @type t :: %LogEntry{query: String.t | (t -> String.t), params: [term],
                       query_time: integer, decode_time: integer | nil,
                       queue_time: integer | nil, connection_pid: pid | nil,
                       result: {:ok, term} | {:error, Exception.t}}
  defstruct query: nil, params: [], query_time: nil, decode_time: nil,
            queue_time: nil, result: nil, connection_pid: nil

  require Logger

  @doc """
  Logs the given entry in debug mode.

  The logger call will be removed at compile time if
  `compile_time_purge_level` is set to higher than debug.
  """
  def log(entry) do
    Logger.debug(fn ->
      {_entry, iodata} = Ecto.LogEntry.to_iodata(entry)
      iodata
    end, ecto_conn_pid: entry.connection_pid)
    entry
  end

  @doc """
  Logs the given entry in the given level.

  The logger call won't be removed at compile time as
  custom level is given.
  """
  def log(entry, level) do
    Logger.log(level, fn ->
      {_entry, iodata} = Ecto.LogEntry.to_iodata(entry)
      iodata
    end, ecto_conn_pid: entry.connection_pid)
    entry
  end

  @doc """
  Converts a log entry into iodata.

  The entry is automatically resolved if it hasn't been yet.
  """
  def to_iodata(entry) do
    %{query_time: query_time, decode_time: decode_time, queue_time: queue_time,
      params: params, query: query, result: result} = entry

    params = Enum.map params, fn
      %Ecto.Query.Tagged{value: value} -> value
      value -> value
    end

    {entry, [query, ?\s, inspect(params, char_lists: false), ?\s, ok_error(result),
             time("query", query_time, true), time("decode", decode_time, false),
             time("queue", queue_time, false)]}
  end

  ## Helpers

  defp ok_error({:ok, _}),    do: "OK"
  defp ok_error({:error, _}), do: "ERROR"

  defp time(_label, nil, _force), do: []
  defp time(label, time, force) do
    ms = div(time, 100) / 10
    if force or ms > 0 do
      [?\s, label, ?=, :io_lib_format.fwrite_g(ms), ?m, ?s]
    else
      []
    end
  end
end
