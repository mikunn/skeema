defmodule Skeema do
  @moduledoc """
  Turn your nested Ecto schema into a map.
  """
  alias Skeema.Fields

  @type callback() :: (ecto_schema() -> term())
  @typep ecto_schema() :: struct()

  @doc """
  Turns the provided Ecto schema into a map.

  Traverses the provided Ecto schema turning each schema into a map.
  If an association inside a schema is not loaded, the returned map
  will have the value retained as an `Ecto.Association.NotLoaded` struct.

  The function returns an `:ok` tuple. The option to return an `:error`
  tuple is reserved for future needs.

  This function is a shortcut for
  ```
  Skeema.decode(schema, fn schema -> Fields.take_all(schema) end)
  ```
  """
  @spec decode(ecto_schema()) :: {:ok, map()}
  def decode(%_{} = schema) do
    callback = fn schema ->
      Fields.take_all(schema, if_not_loaded: :ignore)
    end

    decode(schema, callback)
  end

  @doc """
  Turns the provided Ecto schema into a map with fine-grained control.

  The second parameter is a callback function that gets executed whenever
  a schema is encountered. The schema is passed into the function and the
  function should return the map version of that schema.

  The function returns an `:ok` tuple. The option to return an `:error`
  tuple is reserved for future needs.

  See the [README](readme.html) for examples of usage.

  """
  @spec decode(ecto_schema(), callback()) :: {:ok, map()}
  def decode(%_{} = schema, fun) when is_function(fun) do
    {:ok, do_decode(schema, fun)}
  end

  @doc """
  Turns the provided Ecto schema into a map.

  Similar to `decode/1` except that this returns the map directly
  without wrapping it in an `:ok` tuple.
  """
  @spec decode!(ecto_schema()) :: map()
  def decode!(%_{} = schema) do
    {:ok, decoded} = decode(schema)
    decoded
  end

  @doc """
  Turns the provided Ecto schema into a map with fine-grained control.

  Similar to `decode/2` except that this returns the map directly
  without wrapping it in an `:ok` tuple.
  """

  @spec decode!(ecto_schema(), callback()) :: map()
  def decode!(%_{} = schema, fun) when is_function(fun) do
    {:ok, decoded} = decode(schema, fun)
    decoded
  end

  defp do_decode(%_{} = schema, fun) do
    if is_schema?(schema) do
      map =
        try do
          fun.(schema)
        rescue
          FunctionClauseError ->
            Fields.take_all(schema, if_not_loaded: :ignore)
        end

      if is_map(map) and not is_struct(map) do
        map
        |> Enum.map(fn {key, val} -> {key, do_decode(val, fun)} end)
        |> Enum.into(%{})
      else
        schema
      end
    else
      schema
    end
  end

  defp do_decode([%{} | _] = schema, fun) do
    Enum.map(schema, fn item -> do_decode(item, fun) end)
  end

  defp do_decode(other, _fun) do
    other
  end

  defp is_schema?(%mod{}) do
    Keyword.has_key?(mod.__info__(:functions), :__schema__)
  end
end
