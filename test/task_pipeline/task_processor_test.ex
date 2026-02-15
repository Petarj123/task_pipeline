defmodule TaskPipeline.TaskProcessorTest do
  use TaskPipeline.DataCase
  use Oban.Testing, repo: TaskPipeline.Repo

  alias TaskPipeline.Tasks
  alias TaskPipeline.Workers.TaskProcessor
  import TaskPipeline.TasksFixtures

  describe "perform/1" do
    test "claims queued task, completes it, and records a success attempt" do
      task = task_fixture(%{priority: :critical, max_attempts: 3})
      :rand.seed(:exsplus, {1, 2, 3})

      assert :ok = TaskProcessor.perform(%Oban.Job{args: %{"task_id" => task.id}, attempt: 1})

      updated = Tasks.get_task!(task.id)
      assert updated.status == :completed
      assert length(updated.attempts) == 1

      [attempt] = updated.attempts
      assert fetch_attempt_value(attempt, "attempt") == 1
      assert fetch_attempt_value(attempt, "result") == "success"
      assert fetch_attempt_value(attempt, "timestamp")
    end

    test "returns error, requeues task, and records failed attempt before max retries" do
      task = task_fixture(%{priority: :critical, max_attempts: 3})
      :rand.seed(:exsplus, {2, 3, 4})

      assert {:error, "Simulated random failure"} =
               TaskProcessor.perform(%Oban.Job{args: %{"task_id" => task.id}, attempt: 1})

      updated = Tasks.get_task!(task.id)
      assert updated.status == :queued
      assert length(updated.attempts) == 1

      [attempt] = updated.attempts
      assert fetch_attempt_value(attempt, "attempt") == 1
      assert fetch_attempt_value(attempt, "result") == "error"
      assert fetch_attempt_value(attempt, "error") == "Simulated random failure"
      assert fetch_attempt_value(attempt, "timestamp")
    end

    test "marks task failed and returns max-attempts error on final retry" do
      task = raw_task_fixture(%{priority: :critical, max_attempts: 2})
      :rand.seed(:exsplus, {2, 3, 4})

      assert {:error, "Max attempts exhausted"} =
               TaskProcessor.perform(%Oban.Job{args: %{"task_id" => task.id}, attempt: 2})

      updated = Tasks.get_task!(task.id)
      assert updated.status == :failed
      assert length(updated.attempts) == 1

      [attempt] = updated.attempts
      assert fetch_attempt_value(attempt, "attempt") == 2
      assert fetch_attempt_value(attempt, "result") == "error"
      assert fetch_attempt_value(attempt, "error") == "Simulated random failure"
    end

    test "skips processing when task is already claimed by another worker" do
      task = task_fixture()
      assert {:ok, _claimed} = Tasks.claim_task_for_processing(task.id)

      assert :ok = TaskProcessor.perform(%Oban.Job{args: %{"task_id" => task.id}, attempt: 1})

      updated = Tasks.get_task!(task.id)
      assert updated.status == :processing
      assert updated.attempts == []
    end
  end

  defp fetch_attempt_value(attempt_map, key) do
    Map.get(attempt_map, key) || Map.get(attempt_map, String.to_existing_atom(key))
  end
end
