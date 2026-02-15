defmodule TaskPipelineWeb.TaskJSON do
  alias TaskPipeline.Tasks.Task

  @doc """
  Renders a list of tasks.
  """
  def index(%{tasks: tasks}) do
    %{data: for(task <- tasks, do: data(task))}
  end

  @doc """
  Renders a single task.
  """
  def show(%{task: task}) do
    %{data: data(task)}
  end

  @doc """
  Renders task summary.
  """
  def summary(%{summary: summary}) do
    %{data: summary}
  end

  defp data(%Task{} = task) do
    %{
      id: task.id,
      title: task.title,
      type: task.type,
      priority: task.priority,
      payload: task.payload,
      max_attempts: task.max_attempts,
      status: task.status,
      attempts: task.attempts
    }
  end
end
