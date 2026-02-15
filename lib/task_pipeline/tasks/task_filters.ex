defmodule TaskPipeline.Tasks.TaskFilters do
  @moduledoc """
  Embedded schema for validating task filter parameters.

  Converts string filter values from HTTP requests into validated atoms
  for database queries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  @statuses ~w(queued processing completed failed)
  @types ~w(import export report cleanup)
  @priorities ~w(low normal high critical)

  embedded_schema do
    field(:status, :string)
    field(:type, :string)
    field(:priority, :string)
  end

  @doc false
  def changeset(filters, params) do
    filters
    |> cast(params, [:status, :type, :priority])
    |> validate_inclusion(:status, @statuses,
      message: "must be one of: #{Enum.join(@statuses, ", ")}"
    )
    |> validate_inclusion(:type, @types, message: "must be one of: #{Enum.join(@types, ", ")}")
    |> validate_inclusion(:priority, @priorities,
      message: "must be one of: #{Enum.join(@priorities, ", ")}"
    )
  end

  @doc """
  Parses and validates filter parameters from HTTP request.

  Returns:
    * `{:ok, filters}` - Valid filters as atom map
    * `{:error, changeset}` - Invalid filters with errors

  ## Examples

      iex> parse(%{"status" => "queued"})
      {:ok, %{status: :queued}}

      iex> parse(%{"status" => "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def parse(params) do
    cs = changeset(%__MODULE__{}, params)

    if cs.valid? do
      {:ok, cs |> apply_changes() |> to_atoms()}
    else
      {:error, cs}
    end
  end

  defp to_atoms(%__MODULE__{} = f) do
    f
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, String.to_existing_atom(v)} end)
  end
end
