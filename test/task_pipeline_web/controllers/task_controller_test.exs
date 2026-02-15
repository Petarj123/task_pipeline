defmodule TaskPipelineWeb.TaskControllerTest do
  use TaskPipelineWeb.ConnCase
  use Oban.Testing, repo: TaskPipeline.Repo

  import TaskPipeline.TasksFixtures

  @create_attrs %{
    priority: :low,
    type: :cleanup,
    max_attempts: 4,
    title: "cleanup temp files",
    payload: %{"path" => "/tmp/reports"}
  }

  @invalid_create_attrs %{
    title: nil,
    type: nil,
    payload: nil,
    max_attempts: 0
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GET /api/tasks" do
    test "returns tasks sorted by priority then newest first", %{conn: conn} do
      raw_task_fixture(%{
        priority: :low,
        title: "low old",
        inserted_at: ~N[2026-01-01 10:00:00],
        updated_at: ~N[2026-01-01 10:00:00]
      })

      raw_task_fixture(%{
        priority: :critical,
        title: "critical old",
        inserted_at: ~N[2026-01-01 11:00:00],
        updated_at: ~N[2026-01-01 11:00:00]
      })

      raw_task_fixture(%{
        priority: :high,
        title: "high newest",
        inserted_at: ~N[2026-01-01 13:00:00],
        updated_at: ~N[2026-01-01 13:00:00]
      })

      raw_task_fixture(%{
        priority: :critical,
        title: "critical newest",
        inserted_at: ~N[2026-01-01 14:00:00],
        updated_at: ~N[2026-01-01 14:00:00]
      })

      conn = get(conn, ~p"/api/tasks")
      tasks = json_response(conn, 200)["data"]

      assert Enum.map(tasks, & &1["title"]) == [
               "critical newest",
               "critical old",
               "high newest",
               "low old"
             ]
    end

    test "filters by status, type, and priority together", %{conn: conn} do
      raw_task_fixture(%{status: :queued, type: :import, priority: :high, title: "matching"})
      raw_task_fixture(%{status: :queued, type: :export, priority: :high, title: "wrong type"})

      raw_task_fixture(%{
        status: :completed,
        type: :import,
        priority: :high,
        title: "wrong status"
      })

      conn = get(conn, ~p"/api/tasks?status=queued&type=import&priority=high")
      tasks = json_response(conn, 200)["data"]

      assert length(tasks) == 1
      assert hd(tasks)["title"] == "matching"
    end

    test "returns 422 for invalid filters", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks?status=invalid")
      response = json_response(conn, 422)

      assert response["errors"] != %{}

      assert response["errors"]["status"] == [
               "must be one of: queued, processing, completed, failed"
             ]
    end
  end

  describe "POST /api/tasks" do
    test "creates task, returns 201, and sets location header", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @create_attrs)
      %{"data" => data} = json_response(conn, 201)

      assert is_integer(data["id"])
      assert data["title"] == "cleanup temp files"
      assert data["type"] == "cleanup"
      assert data["priority"] == "low"
      assert data["payload"] == %{"path" => "/tmp/reports"}
      assert data["max_attempts"] == 4
      assert data["status"] == "queued"
      assert data["attempts"] == []
      assert get_resp_header(conn, "location") == ["/api/tasks/#{data["id"]}"]
    end

    test "enqueues worker job with task id and max attempts", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @create_attrs)
      %{"id" => id} = json_response(conn, 201)["data"]

      assert_enqueued(
        worker: TaskPipeline.Workers.TaskProcessor,
        args: %{"task_id" => id},
        max_attempts: 4
      )
    end

    test "ignores status and attempts from request payload", %{conn: conn} do
      attrs =
        Map.merge(@create_attrs, %{
          status: :failed,
          attempts: [%{attempt: 1, result: "error"}]
        })

      conn = post(conn, ~p"/api/tasks", task: attrs)
      data = json_response(conn, 201)["data"]

      assert data["status"] == "queued"
      assert data["attempts"] == []
    end

    test "returns 422 with validation errors for invalid payload", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @invalid_create_attrs)
      response = json_response(conn, 422)

      assert response["errors"] != %{}
      assert response["errors"]["title"] == ["can't be blank"]
      assert response["errors"]["type"] == ["can't be blank"]
      assert response["errors"]["payload"] == ["can't be blank"]
      assert response["errors"]["max_attempts"] == ["must be greater than 0"]
    end
  end

  describe "GET /api/tasks/:id" do
    test "returns task with full details including attempts", %{conn: conn} do
      task =
        raw_task_fixture(%{
          title: "report task",
          type: :report,
          priority: :critical,
          payload: %{"report_id" => 123},
          max_attempts: 3,
          status: :processing,
          attempts: [%{attempt: 1, result: "error", error: "timeout"}]
        })

      conn = get(conn, ~p"/api/tasks/#{task.id}")
      data = json_response(conn, 200)["data"]

      assert data["id"] == task.id
      assert data["title"] == "report task"
      assert data["type"] == "report"
      assert data["priority"] == "critical"
      assert data["payload"] == %{"report_id" => 123}
      assert data["max_attempts"] == 3
      assert data["status"] == "processing"
      assert data["attempts"] == [%{"attempt" => 1, "error" => "timeout", "result" => "error"}]
    end

    test "returns 404 when task does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks/-1")
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "GET /api/tasks/summary" do
    test "returns zeros when there are no tasks", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks/summary")

      assert %{
               "queued" => 0,
               "processing" => 0,
               "completed" => 0,
               "failed" => 0
             } = json_response(conn, 200)["data"]
    end

    test "returns aggregate counts for all statuses", %{conn: conn} do
      raw_task_fixture(%{status: :queued})
      raw_task_fixture(%{status: :queued})
      raw_task_fixture(%{status: :processing})
      raw_task_fixture(%{status: :completed})
      raw_task_fixture(%{status: :failed})

      conn = get(conn, ~p"/api/tasks/summary")

      assert %{
               "queued" => 2,
               "processing" => 1,
               "completed" => 1,
               "failed" => 1
             } = json_response(conn, 200)["data"]
    end
  end
end
