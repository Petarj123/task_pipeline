# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TaskPipeline.Repo.insert!(%TaskPipeline.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TaskPipeline.Repo
alias TaskPipeline.Tasks.Task

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

tasks = [
  %{
    title: "Import customer CSV",
    type: :import,
    priority: :critical,
    payload: %{"source" => "s3://imports/customers.csv"},
    max_attempts: 3,
    status: :queued,
    attempts: [],
    inserted_at: now,
    updated_at: now
  },
  %{
    title: "Generate revenue report",
    type: :report,
    priority: :high,
    payload: %{"period" => "2026-02"},
    max_attempts: 4,
    status: :processing,
    attempts: [%{attempt: 1, timestamp: now, result: "started"}],
    inserted_at: now,
    updated_at: now
  },
  %{
    title: "Export billing archive",
    type: :export,
    priority: :normal,
    payload: %{"destination" => "s3://exports/billing.zip"},
    max_attempts: 2,
    status: :completed,
    attempts: [%{attempt: 1, timestamp: now, result: "success"}],
    inserted_at: now,
    updated_at: now
  },
  %{
    title: "Cleanup stale temp files",
    type: :cleanup,
    priority: :low,
    payload: %{"path" => "/tmp/task_pipeline"},
    max_attempts: 2,
    status: :failed,
    attempts: [
      %{attempt: 1, timestamp: now, result: "error", error: "Permission denied"},
      %{attempt: 2, timestamp: now, result: "error", error: "Permission denied"}
    ],
    inserted_at: now,
    updated_at: now
  }
]

Repo.insert_all(Task, tasks)
