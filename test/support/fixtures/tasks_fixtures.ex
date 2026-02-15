defmodule TaskPipeline.TasksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TaskPipeline.Tasks` context.
  """
  alias TaskPipeline.Repo
  alias TaskPipeline.Tasks.Task

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        attempts: [],
        max_attempts: 42,
        payload: %{},
        priority: :normal,
        status: :queued,
        title: "some title",
        type: :import
      })
      |> TaskPipeline.Tasks.create_task()

    task
  end

  @doc """
  Generates a task, bypassing changeset.
  """
  def raw_task_fixture(attrs \\ %{}) do
    defaults = %{
      title: "raw title",
      type: :import,
      priority: :normal,
      payload: %{},
      max_attempts: 3,
      status: :queued,
      attempts: []
    }

    data = Map.merge(defaults, Map.new(attrs))

    %Task{}
    |> Map.merge(data)
    |> Repo.insert!()
  end
end
