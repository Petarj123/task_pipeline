defmodule TaskPipeline.Tasks do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias TaskPipeline.Repo
  alias TaskPipeline.Tasks.Task
  alias TaskPipeline.Tasks.TaskFilters

  @doc """
  Returns the list of tasks with optional filtering and sorting.

  Returns:
    * `{:ok, tasks}` when filters are valid
    * `{:error, changeset}` when filters are invalid

  Tasks are sorted by priority (critical, high, normal, low)
  and then by creation time (newest first).

  ## Filters

    * `status` - Filter by task status ("queued", "processing", "completed", "failed")
    * `type` - Filter by task type ("import", "export", "report", "cleanup")
    * `priority` - Filter by priority ("low", "normal", "high", "critical")

  ## Examples

      iex> list_tasks(%{})
      {:ok, [%Task{}, ...]}

      iex> list_tasks(%{"status" => "queued"})
      {:ok, [%Task{status: :queued}, ...]}

      iex> list_tasks(%{"type" => "import", "priority" => "high"})
      {:ok, [%Task{type: :import, priority: :high}, ...]}

      iex> list_tasks(%{"status" => "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def list_tasks(params) do
    with {:ok, filters} <- TaskFilters.parse(params) do
      tasks =
        Task
        |> apply_filters(filters)
        |> order_by([t], [
          fragment("CASE
            WHEN ? = 'critical' THEN 1
            WHEN ? = 'high' THEN 2
            WHEN ? = 'normal' THEN 3
            WHEN ? = 'low' THEN 4
          END", t.priority, t.priority, t.priority, t.priority),
          desc: t.inserted_at
        ])
        |> Repo.all()

      {:ok, tasks}
    end
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.

  ## Examples

      iex> get_task!(123)
      %Task{}

      iex> get_task!(456)
      ** (Ecto.NoResultsError)

  """
  def get_task!(id), do: Repo.get!(Task, id)

  @doc """
  Gets a single task by id.

  Returns:
    * `{:ok, task}` when the task exists
    * `{:error, :not_found}` when the task does not exist

  ## Examples

      iex> get_task(123)
      {:ok, %Task{}}

      iex> get_task(456)
      {:error, :not_found}
  """
  def get_task(id) do
    case Repo.get(Task, id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  @doc """
  Creates a task.

  ## Examples

      iex> create_task(%{field: value})
      {:ok, %Task{}}

      iex> create_task(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task.

  ## Examples

      iex> update_task(task, %{field: new_value})
      {:ok, %Task{}}

      iex> update_task(task, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.

  ## Examples

      iex> change_task(task)
      %Ecto.Changeset{data: %Task{}}

  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  @doc """
  Returns aggregate counts of tasks grouped by status.

  Always returns all four statuses with a count, even if zero.

  ## Examples

      iex> get_summary()
      %{queued: 5, processing: 2, completed: 12, failed: 1}

      iex> get_summary()
      %{queued: 0, processing: 0, completed: 0, failed: 0}

  """
  def get_summary() do
    counts =
      Task
      |> group_by([t], t.status)
      |> select([t], {t.status, count(t.id)})
      |> Repo.all()
      |> Enum.into(%{})

    %{
      queued: 0,
      processing: 0,
      completed: 0,
      failed: 0
    }
    |> Map.merge(counts)
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, value}, query when value != nil ->
        where(query, [t], t.status == ^value)

      {:type, value}, query when value != nil ->
        where(query, [t], t.type == ^value)

      {:priority, value}, query when value != nil ->
        where(query, [t], t.priority == ^value)

      _, query ->
        query
    end)
  end
end
