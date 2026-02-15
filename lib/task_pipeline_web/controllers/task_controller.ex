defmodule TaskPipelineWeb.TaskController do
  use TaskPipelineWeb, :controller

  alias TaskPipeline.Tasks
  alias TaskPipeline.Tasks.Task

  action_fallback TaskPipelineWeb.FallbackController

  def index(conn, params) do
    with {:ok, tasks} <- Tasks.list_tasks(params) do
      render(conn, :index, tasks: tasks)
    end
  end

  def create(conn, %{"task" => task_params}) do
    with {:ok, %Task{} = task} <- Tasks.create_task(task_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/tasks/#{task}")
      |> render(:show, task: task)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, task} <- Tasks.get_task(id) do
      render(conn, :show, task: task)
    end
  end

  def summary(conn, _params) do
    summary = Tasks.get_summary()
    render(conn, :summary, summary: summary)
  end
end
