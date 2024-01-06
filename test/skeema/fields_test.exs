defmodule Skeema.FieldsTest.TestParentSchema do
  use Ecto.Schema

  schema "test_parent_schema" do
    has_many(:has_many, Skeema.FieldsTest.TestSchema)
  end
end

defmodule Skeema.FieldsTest.TestSchema do
  use Ecto.Schema

  schema "test_schema" do
    field(:plain, :string)
    field(:virtual, :string, virtual: true)
    embeds_many(:embeds_many, Skeema.FieldsTest.TestEmbeddedSchema)
    has_many(:has_many, Skeema.FieldsTest.TestAssociationSchema)
    belongs_to(:belongs_to, Skeema.FieldsTest.TestParentSchema)
  end
end

defmodule Skeema.FieldsTest.TestEmbeddedSchema do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:plain, :string)
  end
end

defmodule Skeema.FieldsTest.TestAssociationSchema do
  use Ecto.Schema

  schema "test_association_schema" do
    field(:plain, :string)
  end
end

defmodule Skeema.FieldsTest do
  use ExUnit.Case, async: true

  alias Skeema.Fields

  alias Skeema.FieldsTest.{
    TestSchema,
    TestParentSchema,
    TestEmbeddedSchema,
    TestAssociationSchema
  }

  @schema %TestSchema{
    id: 1,
    plain: "plain",
    virtual: "virtual",
    embeds_many: [
      %TestEmbeddedSchema{
        plain: "plain"
      }
    ],
    has_many: [%TestAssociationSchema{id: 1, plain: "plain"}],
    belongs_to: %TestParentSchema{id: 1, has_many: []},
    belongs_to_id: 1
  }

  describe "take_all/1" do
    test "takes all fields from the schema returning a map" do
      expected = %{
        id: @schema.id,
        plain: @schema.plain,
        virtual: @schema.virtual,
        embeds_many: @schema.embeds_many,
        has_many: @schema.has_many,
        belongs_to: @schema.belongs_to,
        belongs_to_id: @schema.belongs_to_id
      }

      assert Fields.take_all(@schema) == expected
    end
  end

  describe "take_all/2" do
    test "excludes fields given via :except option" do
      expected = %{
        id: @schema.id,
        virtual: @schema.virtual,
        embeds_many: @schema.embeds_many,
        belongs_to: @schema.belongs_to,
        belongs_to_id: @schema.belongs_to_id
      }

      assert Fields.take_all(@schema, except: [:plain, :has_many]) == expected
    end

    test "not loaded associations are handled according to the :if_not_loaded option" do
      updated_schema = Map.put(@schema, :has_many, %Ecto.Association.NotLoaded{})
      excluded_fields = [:virtual, :embeds_many, :belongs_to, :belongs_to_id]

      test_cases = [
        %{
          given: :ignore,
          expect: %{id: @schema.id, plain: @schema.plain, has_many: %Ecto.Association.NotLoaded{}}
        },
        %{
          given: :exclude,
          expect: %{id: @schema.id, plain: @schema.plain}
        },
        %{
          given: {:set_to, :new_value},
          expect: %{id: @schema.id, plain: @schema.plain, has_many: :new_value}
        }
      ]

      for %{given: if_not_loaded_option, expect: expected} <- test_cases do
        result =
          Fields.take_all(updated_schema,
            except: excluded_fields,
            if_not_loaded: if_not_loaded_option
          )

        assert result == expected
      end
    end

    test ":if_not_loaded option doesn't affect loaded associations" do
      excluded_fields = [:virtual, :embeds_many, :belongs_to, :belongs_to_id]
      if_not_loaded_options = [:ignore, :exclude, {:set_to, :new_value}]

      expected = %{id: @schema.id, plain: @schema.plain, has_many: @schema.has_many}

      for if_not_loaded_option <- if_not_loaded_options do
        result =
          Fields.take_all(@schema, except: excluded_fields, if_not_loaded: if_not_loaded_option)

        assert result == expected
      end
    end

    test ":if_not_loaded option is ignored for a field listed in :except option" do
      updated_schema = Map.put(@schema, :has_many, %Ecto.Association.NotLoaded{})

      result =
        Fields.take_all(updated_schema, except: [:has_many], if_not_loaded: {:set_to, :new_value})

      refute Map.has_key?(result, :has_many)
    end
  end

  describe "take_selected/1" do
    test "takes the specified fields from the schema returning a map" do
      selected_fields = [:id, :plain, :has_many, :belongs_to]

      expected = %{
        id: @schema.id,
        plain: @schema.plain,
        has_many: @schema.has_many,
        belongs_to: @schema.belongs_to
      }

      assert Fields.take_selected(@schema, selected_fields) == expected
    end
  end

  describe "take_selected/2" do
    test "not loaded associations are handled according to the :if_not_loaded option" do
      updated_schema = Map.put(@schema, :has_many, %Ecto.Association.NotLoaded{})
      selected_fields = [:id, :plain, :has_many]

      test_cases = [
        %{
          given: :ignore,
          expect: %{id: @schema.id, plain: @schema.plain, has_many: %Ecto.Association.NotLoaded{}}
        },
        %{
          given: :exclude,
          expect: %{id: @schema.id, plain: @schema.plain}
        },
        %{
          given: {:set_to, :new_value},
          expect: %{id: @schema.id, plain: @schema.plain, has_many: :new_value}
        }
      ]

      for %{given: if_not_loaded_option, expect: expected} <- test_cases do
        result =
          Fields.take_selected(updated_schema, selected_fields,
            if_not_loaded: if_not_loaded_option
          )

        assert result == expected
      end
    end

    test ":if_not_loaded option doesn't affect loaded associations" do
      selected_fields = [:id, :plain, :has_many]
      if_not_loaded_options = [:ignore, :exclude, {:set_to, :new_value}]

      expected = %{id: @schema.id, plain: @schema.plain, has_many: @schema.has_many}

      for if_not_loaded_option <- if_not_loaded_options do
        result =
          Fields.take_selected(@schema, selected_fields, if_not_loaded: if_not_loaded_option)

        assert result == expected
      end
    end
  end
end
