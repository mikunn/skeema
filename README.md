# Skeema

A module to turn a nested Ecto schema into a nested map.

**This project may not be maintained, so please don't depend on this repo!**

## Usage

Suppose we have Ecto schemas `PetOwner` and `Pet` and the following struct:

```elixir
schema = %PetOwner{
  name: "Jane Doe",
  pets: [
    %Pet{species: "Cat", name: "Fluffy"}
  ]
}
```

and we would like to turn this into the following map:

```elixir
%{
  name: "Jane Doe",
  pets: [
    %{species: "Cat", name: "Fluffy"}
  ]
}
```

There are many ways to achieve this with the decoding functions depending
on the requirements, but let's look at a few of those.

### Taking all fields

To take all fields (also those added in the future, but ignoring `__struct__`
and other struct/schema internal fields), we could simply use `Skeema.decode/1`
or `Skeema.decode!/1`:

```elixir
Skeema.decode(schema)
```

Simple enough. But what if we would want to take only those specific fields
and ignore whatever fields are added later? We can use `Skeema.decode/2` or
`Skeema.decode!/2` to achieve that:

```elixir
Skeema.decode(schema, fn
  %PetOwner{} = schema -> Map.take(schema, [:name, :pets])
  %Pet{} = schema -> Map.take(schema, [:species, :name])
end)
```

The decode function traverses through the nested schema and passes each schema
to the given callback function. We then turn the schema into a map with
`Map.take/2` and the struct is being replaced with the map. Note that
we will need to take `:pets` from `PetOwner` schema, as otherwise we will
never iterate through `:pets`.

Great! But what if we would want to take the specific fields from `PetOwner`
but all fields from `Pet`?

### More control over the fields

The `Skeema.Fields` module contains functions to help take fields with
more control. If we wanted to take specific fields from `PetOwner` but all
fields from `Pet`, we could achieve that as follows:

```elixir
Skeema.decode(schema, fn
  %PetOwner{} = schema -> Fields.take_selected(schema, [:name, :pets])
  %Pet{} = schema -> Fields.take_all(schema)
end)
```

`Skeema.Fields.take_all/1` takes all fields from the schema except the fields
internal to structs and schemas. And since it is such a common case to take all
fields, we could just remove the whole line:

```elixir
Skeema.decode(schema, fn
  %PetOwner{} = schema -> Fields.take_selected(schema, [:name, :pets])
end)
```

If the function doesn't match a schema, all fields are taken from that schema.
This way we can only focus on the exceptions to the rule if we wish to do so.

So whats the difference between `Skeema.Fields.take_selected/2` and `Map.take/2`?
Well, you can't use the former to take fields such as `__struct__` that are
internal to structs and schemas. But more importantly, it can be passed an option
to control what to do if an association is not loaded.

### Handling `%Ecto.Association.NotLoaded{...}`

What would happen if `:pets` would not be loaded and the value would be
`%Ecto.Association.NotLoaded{...}` instead of a list? With all the implementations
so far, the result map would be simply

```elixir
%{
  name: "Jane Doe",
  pets: %Ecto.Association.NotLoaded{...}
}
```

The decoding process only decodes schemas and since `%Ecto.Association.NotLoaded{...}`
is not a schema, it is returned as-is. However, we might want to change it to
something else or we might want to drop `:pets` entirely. That is where the
`:if_not_loaded` option comes in. The following code will change the value to `[]`:

```elixir
Skeema.decode(schema, fn
  %PetOwner{} = schema ->
    Fields.take_selected(schema, [:name, :pets], if_not_loaded: {:set_to, []})
end)
```

So the resulting map will look as follows:

```elixir
%{
  name: "Jane Doe",
  pets: []
}
```

`:name` field is not affected, since the value is not `%Ecto.Association.NotLoaded{...}`

We can also exclude `:pets` from to result map, by setting `:if_not_loaded` to
`:exclude`. The default value for the option is `:ignore`.

Please see `Skeema.Fields` for more information on the functions and their options.
