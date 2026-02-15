defmodule TaskPipeline.Workers.TaskProcessor do
  @moduledoc """
  Oban worker for processing tasks asynchronously.
  """

  use Oban.Worker, unique: [period: 60, fields: [:args]]
  alias TaskPipeline.Tasks
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}, attempt: attempt}) do
    case Tasks.claim_task_for_processing(task_id) do
      {:ok, task} ->
        task
        |> simulate_task()
        |> handle_attempt(task, attempt)

      {:error, :not_claimed} ->
        Logger.info("Task #{task_id} not claimed, skipping")
        :ok
    end
  end

  @doc """
  Schedules an Oban job for the given task.

  Creates a new Oban job with the task's max_attempts configuration.
  The job will be enqueued immediately and processed by the next available worker.

  ## Examples

      iex> task = %Task{id: 1, max_attempts: 5}
      iex> TaskProcessor.schedule(task)
      {:ok, %Oban.Job{}}
  """
  def schedule(task) do
    %{task_id: task.id}
    |> new(max_attempts: task.max_attempts)
    |> Oban.insert()
  end

  defp simulate_task(task) do
    task
    |> calculate_sleep_duration()
    |> Process.sleep()

    if :rand.uniform(100) <= 20 do
      {:error, "Simulated random failure"}
    else
      :ok
    end
  end

  defp handle_attempt(:ok, task, attempt) do
    attempt_data = %{
      attempt: attempt,
      timestamp: NaiveDateTime.utc_now(),
      result: "success"
    }

    new_attempts = task.attempts ++ [attempt_data]

    case Tasks.update_task(task, %{status: :completed, attempts: new_attempts}) do
      {:ok, _task} ->
        Logger.info("Task #{task.id} completed successfully")
        :ok

      {:error, changeset} ->
        Logger.error("Failed to complete task #{task.id}: #{inspect(changeset)}")
        {:error, "Failed to update task"}
    end
  end

  defp handle_attempt({:error, error_message}, task, attempt) do
    attempt_data = %{
      attempt: attempt,
      timestamp: NaiveDateTime.utc_now(),
      result: "error",
      error: error_message
    }

    new_attempts = task.attempts ++ [attempt_data]
    new_status = if attempt >= task.max_attempts, do: :failed, else: :queued

    case Tasks.update_task(task, %{status: new_status, attempts: new_attempts}) do
      {:ok, _task} ->
        if new_status == :failed do
          Logger.info("Task #{task.id} failed after #{attempt} attempts")
          {:error, "Max attempts exhausted"}
        else
          Logger.info("Task #{task.id} failed on attempt #{attempt}, will retry")
          {:error, error_message}
        end

      {:error, changeset} ->
        Logger.error("Failed to update task #{task.id}: #{inspect(changeset)}")
        {:error, "Failed to update task"}
    end
  end

  defp calculate_sleep_duration(%{priority: priority}) do
    case priority do
      :critical -> Enum.random(1000..2000)
      :high -> Enum.random(2000..4000)
      :normal -> Enum.random(4000..6000)
      :low -> Enum.random(6000..8000)
    end
  end
end
