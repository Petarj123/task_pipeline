defmodule TaskPipeline.TasksTest do
  use TaskPipeline.DataCase
  use Oban.Testing, repo: TaskPipeline.Repo

  alias TaskPipeline.Tasks
  alias TaskPipeline.Tasks.Task
  import TaskPipeline.TasksFixtures

  describe "create_task/1" do
    @valid_attrs %{
      title: "ingest csv",
      type: :import,
      priority: :high,
      payload: %{"source" => "s3://bucket/file.csv"},
      max_attempts: 5
    }

    test "creates a queued task with empty attempts and enqueues Oban job" do
      attrs =
        Map.merge(@valid_attrs, %{
          status: :completed,
          attempts: [%{attempt: 1, result: "success"}]
        })

      assert {:ok, %Task{} = task} = Tasks.create_task(attrs)
      assert task.title == "ingest csv"
      assert task.type == :import
      assert task.priority == :high
      assert task.payload == %{"source" => "s3://bucket/file.csv"}
      assert task.max_attempts == 5
      assert task.status == :queued
      assert task.attempts == []

      assert_enqueued(
        worker: TaskPipeline.Workers.TaskProcessor,
        args: %{"task_id" => task.id},
        max_attempts: 5
      )
    end

    test "returns changeset errors for required fields and invalid max_attempts" do
      assert {:error, changeset} =
               Tasks.create_task(%{
                 title: nil,
                 type: nil,
                 payload: nil,
                 max_attempts: 0
               })

      assert %{
               title: ["can't be blank"],
               type: ["can't be blank"],
               payload: ["can't be blank"],
               max_attempts: ["must be greater than 0"]
             } = errors_on(changeset)
    end
  end

  describe "get_task/1 and get_task!/1" do
    test "get_task/1 returns task when present" do
      task = task_fixture()
      assert {:ok, found} = Tasks.get_task(task.id)
      assert found.id == task.id
    end

    test "get_task/1 returns not_found when task is missing" do
      assert {:error, :not_found} = Tasks.get_task(-1)
    end

    test "get_task!/1 raises when task is missing" do
      assert_raise Ecto.NoResultsError, fn ->
        Tasks.get_task!(-1)
      end
    end
  end

  describe "update_task/2" do
    test "updates allowed fields and ignores non-updatable fields" do
      task = task_fixture(%{title: "original"})

      assert {:ok, updated} =
               Tasks.update_task(task, %{
                 status: :processing,
                 attempts: [%{attempt: 1, result: "running"}],
                 title: "ignored title"
               })

      assert updated.status == :processing
      assert updated.title == "original"
      [attempt] = updated.attempts
      assert fetch_attempt_value(attempt, "attempt") == 1
      assert fetch_attempt_value(attempt, "result") == "running"
    end

    test "allows processing -> queued and processing -> completed transitions" do
      processing_task = raw_task_fixture(%{status: :processing})
      processing_task_2 = raw_task_fixture(%{status: :processing})

      assert {:ok, retried} = Tasks.update_task(processing_task, %{status: :queued, attempts: []})
      assert retried.status == :queued

      assert {:ok, completed} =
               Tasks.update_task(processing_task_2, %{status: :completed, attempts: []})

      assert completed.status == :completed
    end

    test "rejects invalid status transition" do
      task = task_fixture()

      assert {:error, changeset} = Tasks.update_task(task, %{status: :completed, attempts: []})

      assert %{status: ["invalid status transition from queued to completed"]} =
               errors_on(changeset)
    end

    test "allows updating attempts without changing status" do
      task = raw_task_fixture(%{status: :processing})

      assert {:ok, updated} =
               Tasks.update_task(task, %{attempts: [%{attempt: 1, result: "retry"}]})

      assert updated.status == :processing

      [attempt] = updated.attempts
      assert fetch_attempt_value(attempt, "attempt") == 1
      assert fetch_attempt_value(attempt, "result") == "retry"
    end
  end

  describe "change_task/2" do
    test "returns a changeset with cast fields and validation errors" do
      changeset =
        Tasks.change_task(%Task{}, %{
          title: nil,
          type: nil,
          payload: nil,
          max_attempts: 0
        })

      refute changeset.valid?

      assert %{title: ["can't be blank"], type: ["can't be blank"], payload: ["can't be blank"]} =
               errors_on(changeset)

      assert %{max_attempts: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  describe "list_tasks/1" do
    test "returns tasks sorted by priority then newest first" do
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

      assert {:ok, tasks} = Tasks.list_tasks(%{})

      assert Enum.map(tasks, & &1.title) == [
               "critical newest",
               "critical old",
               "high newest",
               "low old"
             ]
    end

    test "applies combined filters" do
      matching = raw_task_fixture(%{status: :queued, type: :import, priority: :high})
      raw_task_fixture(%{status: :queued, type: :export, priority: :high})
      raw_task_fixture(%{status: :completed, type: :import, priority: :high})

      assert {:ok, [task]} =
               Tasks.list_tasks(%{"status" => "queued", "type" => "import", "priority" => "high"})

      assert task.id == matching.id
    end

    test "returns error changeset for invalid filters" do
      assert {:error, changeset} = Tasks.list_tasks(%{"status" => "bad"})

      assert %{status: ["must be one of: queued, processing, completed, failed"]} =
               errors_on(changeset)
    end
  end

  describe "get_summary/0" do
    test "returns all statuses with zeros when empty" do
      assert %{queued: 0, processing: 0, completed: 0, failed: 0} = Tasks.get_summary()
    end

    test "returns aggregate counts across all statuses" do
      raw_task_fixture(%{status: :queued})
      raw_task_fixture(%{status: :queued})
      raw_task_fixture(%{status: :processing})
      raw_task_fixture(%{status: :completed})
      raw_task_fixture(%{status: :failed})

      assert %{queued: 2, processing: 1, completed: 1, failed: 1} = Tasks.get_summary()
    end
  end

  defp fetch_attempt_value(attempt_map, key) do
    Map.get(attempt_map, key) || Map.get(attempt_map, String.to_existing_atom(key))
  end
end
