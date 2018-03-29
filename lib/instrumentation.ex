defmodule Instrumentation do
  @moduledoc ~S"""
  Simple instrumentation framework inspired by ActiveSupport::Notifications.

  It's basically syntactic sugar for a pubsub system based on Elixir's `Registry` module.

  ```
  import Instrumentation

  subscribe "foo", fn payload ->
    IO.puts "foo took #{payload[:duration]} ms and said #{payload[:said]}!"
  end

  result = instrument "foo", fn ->
    {some_function(), [said: "hiiii"]}
  end
  ```
  """

  @type namespace :: binary | atom
  @type tag :: binary | atom | nil
  @type target :: tag | Regex.t
  @type payload :: map | Keyword.t
  @type callback :: (payload -> term) | ((tag, payload) -> term)

  @doc """
  Instrument some code.

  The return value of `f` must be a tuple `{result, payload}` where `result` _will
  be the return value of this function_.

  `payload` is of type `t:payload/0` and will be merged into the payload
  that is delivered to the subscribers.

  Subscribers use `namespace` and `tag` to match on and receive notifications.

  ```
  # Without a tag
  users = instrument "foo", fn ->
    {Repo.all(User), some_metadata: "blah"}
  end

  # With a tag
  value = instrument, "memcache", "get", fn ->
    {Memcache.get("foo"), key: "foo"}
  end
  ```
  """
  @spec instrument(namespace, tag, f :: (() -> {term, payload})) :: term
  def instrument(namespace, tag \\ nil, f) do
    tag = normalize_tag(tag)
    start_time = :os.system_time(:millisecond)

    {value, payload} = try do
      f.()
    rescue
      error ->
        duration = :os.system_time(:millisecond) - start_time
        [error: error, duration: duration]
          |> Map.new
          |> notify(namespace, tag)
        reraise(error, System.stacktrace)
    end

    duration = :os.system_time(:millisecond) - start_time

    payload
      |> Map.new
      |> Map.put_new(:duration, duration)
      |> notify(namespace, tag)

    value
  end

  @doc """
  Simply time some code.

  Use this function if you don't have any custom payload that you want to send
  to subscribers; you just want to do simple timings.

  Since there is no payload, the return value of `f` will be the return value
  of this function.

  ```
  "foobar" = time "foo", fn ->
    "foobar"
  end

  value = time "memcache", "get", fn ->
    Memcache.get(key)
  end
  ""
  ```
  """
  @spec time(namespace, tag, (() -> term)) :: term
  def time(namespace, tag \\ nil, f) do
    instrument(namespace, tag, fn -> {f.(), []} end)
  end

  @doc ~S"""
  Subscribe to notifications generated by `instrument/3` and `time/3`.

  If `tag` is `nil`, then the subscription will match _all_ notifications for
  the given `namespace`.

  If `tag` is a `t:Regex.t/0` and a notification's tag is a string, then the regex
  will be run against the string to determine a match.

  `f` can have arity of 1 or 2. If arity is 1, then `payload` is given to the
  function. If arity is 2, then `tag, payload` is given to the function.

  `payload` is a map so you can pattern match on it.

  The `payload` will always have `:duration` in it.

  If instrumentation fails, then `payload[:error]` will be an exception.

  ```
  # Subscribe to all notifications on namespace "foo", regardless of tag.
  subscribe "foo", fn tag, payload ->
    Logger.debug("foo.#{tag} got payload #{inspect(payload)}")
  end

  # Subscribe to only certain tags.
  subscribe "memcache", "get", fn payload ->
    {tag, payload} = Map.pop(payload, :tag)
    Logger.debug("memcache.#{tag} got payload #{inspect(payload)}")
  end

  # Subscribe to only certain tags, but don't put the tag in the payload.
  subscribe "memcache", "get", fn tag, payload ->
    Logger.debug("memcache.#{tag} got payload #{inspect(payload)}")
  end

  # Subscribe using a regex (this requires the notification emit a string tag).
  subscribe "memcache", ~r/get/, fn tag, payload ->
    Logger.debug("memcache.#{tag} got payload #{inspect(payload)}")
  end
  ```
  """
  @spec subscribe(namespace, target, callback) :: term
  def subscribe(namespace, tag \\ nil, f) do
    tag = normalize_tag(tag)
    Registry.register(Instrumentation.Registry, namespace, {tag, f})
  end

  defp notify(payload, namespace, tag) do
    Registry.dispatch(Instrumentation.Registry, namespace, fn entries ->
      Enum.each(entries, &notify_payload(&1, payload, tag))
    end)
  end

  defp notify_payload({_pid, {target, callback}}, payload, tag) do
    if matches?(target, tag) do
      case :erlang.fun_info(callback)[:arity] do
        1 -> callback.(Map.put(payload, :tag, tag))
        2 -> callback.(tag, payload)
        _ -> raise(ArgumentError, "bad arity for subscribe function")
      end
    end
  end

  defp matches?(nil, _), do: true
  defp matches?(target, tag) when is_binary(target), do: target == tag
  defp matches?(target, tag) when is_atom(target), do: target == tag
  defp matches?(target, tag) when is_binary(tag), do: tag =~ target
  defp matches?(_, _), do: false

  defp normalize_tag(nil), do: nil
  defp normalize_tag(tag) when is_atom(tag), do: tag
  defp normalize_tag(tag) when is_binary(tag), do: tag
  defp normalize_tag(tag) do
    if Regex.regex?(tag) do
      tag
    else
      raise(ArgumentError, "invalid tag: #{inspect(tag)}")
    end
  end

end
