defmodule SkeemaTest.TestParentSchema do
  use Ecto.Schema

  schema "test_parent_schema" do
    has_many(:has_many, SkeemaTest.TestSchema)
  end
end

defmodule SkeemaTest.TestSchema do
  use Ecto.Schema

  schema "test_schema" do
    field(:plain, :string)
    field(:virtual, :string, virtual: true)
    embeds_many(:embeds_many_1, SkeemaTest.TestEmbeddedSchema1)
    embeds_many(:embeds_many_2, SkeemaTest.TestEmbeddedSchema2)
    has_many(:has_many, SkeemaTest.TestAssociationSchema1)
    has_one(:has_one, SkeemaTest.TestAssociationSchema2)
    belongs_to(:belongs_to, SkeemaTest.TestParentSchema)
  end
end

defmodule SkeemaTest.TestEmbeddedSchema1 do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:plain, :string)
    field(:virtual, :string, virtual: true)
  end
end

defmodule SkeemaTest.TestEmbeddedSchema2 do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:plain, :string)
    field(:virtual, :string, virtual: true)
    embeds_many(:embeds_many, SkeemaTest.TestEmbeddedSchema1)
  end
end

defmodule SkeemaTest.TestAssociationSchema1 do
  use Ecto.Schema

  schema "test_association_schema_1" do
    field(:plain, :string)
    field(:virtual, :string, virtual: true)
    has_many(:has_many, SkeemaTest.TestAssociationSchema2)
  end
end

defmodule SkeemaTest.TestAssociationSchema2 do
  use Ecto.Schema

  schema "test_association_schema_2" do
    field(:plain, :string)
    field(:virtual, :string, virtual: true)
  end
end

defmodule SkeemaTest do
  use ExUnit.Case, async: true

  alias __MODULE__.{
    TestSchema,
    TestEmbeddedSchema1,
    TestEmbeddedSchema2,
    TestAssociationSchema1,
    TestAssociationSchema2,
    TestParentSchema
  }

  alias Skeema
  alias Skeema.Fields

  @struct %TestSchema{
    id: 1,
    plain: "plain field",
    virtual: "virtual field",
    embeds_many_1: [],
    embeds_many_2: [
      %TestEmbeddedSchema2{
        plain: "plain",
        virtual: "virtual",
        embeds_many: [%TestEmbeddedSchema1{plain: "plain", virtual: "virtual"}]
      }
    ],
    has_many: [
      %TestAssociationSchema1{
        id: 1,
        plain: "plain",
        virtual: "virtual",
        has_many: [%TestAssociationSchema2{id: 1, plain: "plain", virtual: "virtual"}]
      }
    ],
    has_one: %TestAssociationSchema2{id: 2, plain: "plain", virtual: "virtual"},
    belongs_to: %TestParentSchema{id: 1, has_many: []},
    belongs_to_id: 1
  }

  describe "decode/1" do
    test "decodes the nested schema into a map returning it in an :ok tuple" do
      expected_map = %{
        id: @struct.id,
        plain: @struct.plain,
        virtual: @struct.virtual,
        embeds_many_1: [],
        embeds_many_2:
          Enum.map(@struct.embeds_many_2, fn struct ->
            %{
              plain: struct.plain,
              virtual: struct.virtual,
              embeds_many:
                Enum.map(struct.embeds_many, fn struct ->
                  %{
                    plain: struct.plain,
                    virtual: struct.virtual
                  }
                end)
            }
          end),
        has_many:
          Enum.map(@struct.has_many, fn struct ->
            %{
              id: struct.id,
              plain: struct.plain,
              virtual: struct.virtual,
              has_many:
                Enum.map(struct.has_many, fn struct ->
                  %{
                    id: struct.id,
                    plain: struct.plain,
                    virtual: struct.virtual
                  }
                end)
            }
          end),
        has_one: %{
          id: @struct.has_one.id,
          plain: @struct.has_one.plain,
          virtual: @struct.has_one.virtual
        },
        belongs_to: %{
          id: @struct.belongs_to.id,
          has_many: []
        },
        belongs_to_id: @struct.belongs_to_id
      }

      assert {:ok, result_map} = Skeema.decode(@struct)

      assert result_map == expected_map
    end

    test "returns as-is associations that are not loaded" do
      updated_struct =
        @struct
        |> Map.put(:belongs_to, %Ecto.Association.NotLoaded{})
        |> put_in(
          [Access.key!(:has_many), Access.at(0), Access.key!(:has_many)],
          %Ecto.Association.NotLoaded{}
        )

      expected_map = %{
        id: @struct.id,
        plain: @struct.plain,
        virtual: @struct.virtual,
        embeds_many_1: [],
        embeds_many_2:
          Enum.map(@struct.embeds_many_2, fn struct ->
            %{
              plain: struct.plain,
              virtual: struct.virtual,
              embeds_many:
                Enum.map(struct.embeds_many, fn struct ->
                  %{
                    plain: struct.plain,
                    virtual: struct.virtual
                  }
                end)
            }
          end),
        has_many:
          Enum.map(@struct.has_many, fn struct ->
            %{
              id: struct.id,
              plain: struct.plain,
              virtual: struct.virtual,
              has_many: %Ecto.Association.NotLoaded{}
            }
          end),
        has_one: %{
          id: @struct.has_one.id,
          plain: @struct.has_one.plain,
          virtual: @struct.has_one.virtual
        },
        belongs_to: %Ecto.Association.NotLoaded{},
        belongs_to_id: @struct.belongs_to_id
      }

      assert {:ok, result_map} = Skeema.decode(updated_struct)

      assert result_map == expected_map
    end
  end

  describe "decode/2" do
    test "decodes each schema based on the given function" do
      expected_map = %{
        id: 1,
        plain: "plain field",
        virtual: "virtual field",
        embeds_many_2: [
          %{
            plain: "plain",
            embeds_many: [%{plain: "plain", virtual: "virtual"}]
          }
        ],
        has_many: [
          %{
            plain: "plain",
            has_many: [%{virtual: "virtual"}]
          }
        ],
        has_one: %{virtual: "virtual"},
        belongs_to: %TestParentSchema{id: 1, has_many: []},
        belongs_to_id: 1
      }

      assert {:ok, result_map} =
               Skeema.decode(@struct, fn
                 %TestSchema{} = schema ->
                   Fields.take_all(schema, except: [:embeds_many_1])

                 %TestEmbeddedSchema2{} = schema ->
                   Fields.take_selected(schema, [:plain, :embeds_many])

                 %TestAssociationSchema1{} = schema ->
                   Fields.take_selected(schema, [:plain, :has_many])

                 %TestAssociationSchema2{} = schema ->
                   Map.take(schema, [:virtual])

                 %TestParentSchema{} = schema ->
                   schema
               end)

      assert result_map == expected_map
    end

    test "doesn't iterate through sub-schemas if a schema is not decoded" do
      assert {:ok, result_map} =
               Skeema.decode(@struct, fn
                 %TestSchema{} = schema -> schema
                 %TestAssociationSchema1{} = schema -> Map.take(schema, [:plain])
               end)

      assert result_map == @struct
    end

    test "doesn't decode sub-schemas if a struct is returned" do
      expected_map = %{
        id: @struct.id,
        plain: @struct.plain,
        virtual: @struct.virtual,
        embeds_many_1: [],
        embeds_many_2:
          Enum.map(@struct.embeds_many_2, fn struct ->
            %{
              plain: struct.plain,
              virtual: struct.virtual,
              # this won't be decoded
              embeds_many: struct.embeds_many
            }
          end),
        # this won't be decoded
        has_many: @struct.has_many,
        has_one: %{
          id: @struct.has_one.id,
          plain: @struct.has_one.plain,
          virtual: @struct.has_one.virtual
        },
        belongs_to: %{
          id: @struct.belongs_to.id,
          has_many: []
        },
        belongs_to_id: @struct.belongs_to_id
      }

      assert {:ok, result_map} =
               Skeema.decode(@struct, fn
                 %TestSchema{} = schema -> Fields.take_all(schema)
                 %TestAssociationSchema1{} = schema -> schema
                 %TestEmbeddedSchema1{} = schema -> schema
               end)

      assert result_map == expected_map
    end

    test "handles associations that are not loaded according to the field options" do
      updated_struct =
        @struct
        |> Map.put(:belongs_to, %Ecto.Association.NotLoaded{})
        |> put_in(
          [Access.key!(:has_many), Access.at(0), Access.key!(:has_many)],
          %Ecto.Association.NotLoaded{}
        )

      expected_map = %{
        has_many: [%{id: 1, plain: "plain", virtual: "virtual"}],
        belongs_to: :new_value
      }

      assert {:ok, result_map} =
               Skeema.decode(updated_struct, fn
                 %TestSchema{} = schema ->
                   Fields.take_selected(schema, [:has_many, :belongs_to],
                     if_not_loaded: {:set_to, :new_value}
                   )

                 %TestAssociationSchema1{} = schema ->
                   Fields.take_all(schema, if_not_loaded: :exclude)
               end)

      assert result_map == expected_map
    end
  end

  describe "decode!/1" do
    test "decodes the nested schema into a map and returns it" do
      expected = %{
        id: @struct.id,
        plain: @struct.plain,
        virtual: @struct.virtual,
        embeds_many_1: [],
        embeds_many_2:
          Enum.map(@struct.embeds_many_2, fn struct ->
            %{
              plain: struct.plain,
              virtual: struct.virtual,
              embeds_many:
                Enum.map(struct.embeds_many, fn struct ->
                  %{
                    plain: struct.plain,
                    virtual: struct.virtual
                  }
                end)
            }
          end),
        has_many:
          Enum.map(@struct.has_many, fn struct ->
            %{
              id: struct.id,
              plain: struct.plain,
              virtual: struct.virtual,
              has_many:
                Enum.map(struct.has_many, fn struct ->
                  %{
                    id: struct.id,
                    plain: struct.plain,
                    virtual: struct.virtual
                  }
                end)
            }
          end),
        has_one: %{
          id: @struct.has_one.id,
          plain: @struct.has_one.plain,
          virtual: @struct.has_one.virtual
        },
        belongs_to: %{
          id: @struct.belongs_to.id,
          has_many: []
        },
        belongs_to_id: @struct.belongs_to_id
      }

      assert Skeema.decode!(@struct) == expected
    end
  end

  describe "decode!/2" do
    test "decodes the nested schema into a map according to the given function and returns the map" do
      fun = fn %TestSchema{} = schema ->
        Fields.take_selected(schema, [:id, :plain, :virtual])
      end

      expected = %{
        id: 1,
        plain: "plain field",
        virtual: "virtual field"
      }

      assert Skeema.decode!(@struct, fun) == expected
    end
  end
end
