defmodule Skeema.Fields do
  @moduledoc """
  Functions for taking fields from a schema.
  """
  @type if_not_loaded_option() :: {:if_not_loaded, :ignore | :exclude | {:set_to, term()}}
  @type key() :: atom()
  @typep ecto_schema() :: struct()

  @doc """
  Takes all fields from a schema returning a map.

  The function will ignore fields internal to structs and schemas such as`__schema__`.
  It can also be used to exclude certain fields (see the options below).

  ## Options

    * `:except` - a list of keys to exclude from the returned map.
    * `:if_not_loaded` - what to do if the field's value is
    `%Ecto.Association.NotLoaded{...}`. The possible values are:
      * `:ignore` (default) - the value is returned as-is.
      * `:exclude` - the field is excluded from the returned map.
      * `{:set_to, any()}` - the value is set to the one specified here.
  """
  @spec take_all(ecto_schema(), [if_not_loaded_option() | {:except, key()}]) :: map()
  def take_all(%module{} = schema, options \\ []) do
    if_not_loaded = Keyword.get(options, :if_not_loaded, :ignore)
    excluded_fields = Keyword.get(options, :except, [])

    fields_to_take =
      module
      |> get_fields()
      |> difference(excluded_fields)

    decode_schema(schema, fields_to_take, if_not_loaded)
  end

  @doc """
  Takes the selected fields from a schema returning a map.

  Similar to `Map.take/2`, but can't be used to take `__schema__` or other
  fields internal to structs or schemas. It will also accept a list of options.

  ## Options

    * `:if_not_loaded` - what to do if the field's value is
    `%Ecto.Association.NotLoaded{...}`. The possible values are:
      * `:ignore` (default) - the value is returned as-is.
      * `:exclude` - the field is excluded from the returned map.
      * `{:set_to, any()}` - the value is set to the one specified here.
  """
  @spec take_selected(ecto_schema(), [key()], [if_not_loaded_option()]) :: map()
  def take_selected(%module{} = schema, selected_fields, options \\ []) do
    if_not_loaded = Keyword.get(options, :if_not_loaded, :ignore)

    fields_to_take =
      module
      |> get_fields()
      |> intersection(selected_fields)

    decode_schema(schema, fields_to_take, if_not_loaded)
  end

  defp decode_schema(schema, keys, if_not_loaded_action) do
    keys
    |> Enum.filter(fn key -> Map.has_key?(schema, key) end)
    |> Enum.reduce(%{}, fn
      key, result_map ->
        current_value = get_in(schema, [Access.key!(key)])
        association_is_loaded = not match?(%Ecto.Association.NotLoaded{}, current_value)

        case {association_is_loaded, if_not_loaded_action} do
          {true, _} ->
            Map.put(result_map, key, current_value)

          {false, :ignore} ->
            Map.put(result_map, key, current_value)

          {false, :exclude} ->
            result_map

          {false, {:set_to, new_value}} ->
            Map.put(result_map, key, new_value)
        end
    end)
  end

  defp get_fields(module) do
    [:fields, :virtual_fields, :associations]
    |> Enum.flat_map(fn field_type -> module.__schema__(field_type) end)
    |> Enum.uniq()
  end

  defp difference(list1, list2) do
    MapSet.new(list1)
    |> MapSet.difference(MapSet.new(list2))
    |> MapSet.to_list()
  end

  defp intersection(list1, list2) do
    MapSet.new(list1)
    |> MapSet.intersection(MapSet.new(list2))
    |> MapSet.to_list()
  end
end
