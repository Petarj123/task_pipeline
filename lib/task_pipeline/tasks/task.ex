defmodule TaskPipeline.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field(:title, :string)
    field(:type, Ecto.Enum, values: [:import, :export, :report, :cleanup])
    field(:priority, Ecto.Enum, values: [:low, :normal, :high, :critical], default: :normal)
    field(:payload, :map)
    field(:max_attempts, :integer, default: 3)

    field(:status, Ecto.Enum,
      values: [:queued, :processing, :completed, :failed],
      default: :queued
    )

    field(:attempts, {:array, :map}, default: [])

    timestamps()
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :type, :priority, :payload, :max_attempts])
    |> validate_required([:title, :type, :payload])
    |> validate_number(:max_attempts, greater_than: 0)
    |> apply_check_constraints()
  end

  @doc false
  def update_changeset(task, attrs) do
    task
    |> cast(attrs, [:status, :attempts])
    |> validate_required([:status])
    |> validate_status_transition()
    |> apply_check_constraints()
  end

  defp validate_status_transition(changeset) do
    case get_change(changeset, :status) do
      nil ->
        changeset

      new_status ->
        old_status = changeset.data.status

        if valid_transition?(old_status, new_status) do
          changeset
        else
          add_error(
            changeset,
            :status,
            "invalid status transition from #{old_status} to #{new_status}"
          )
        end
    end
  end

  defp valid_transition?(:queued, :processing), do: true
  defp valid_transition?(:processing, :completed), do: true
  defp valid_transition?(:processing, :queued), do: true
  defp valid_transition?(:processing, :failed), do: true
  defp valid_transition?(_, _), do: false

  defp apply_check_constraints(changeset) do
    changeset
    |> check_constraint(:type, name: :type_must_be_valid, message: "is invalid")
    |> check_constraint(:priority, name: :priority_must_be_valid, message: "is invalid")
    |> check_constraint(:status, name: :status_must_be_valid, message: "is invalid")
  end
end
