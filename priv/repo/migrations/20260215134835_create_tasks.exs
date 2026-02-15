defmodule TaskPipeline.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TYPE task_type AS ENUM ('import', 'export', 'report', 'cleanup')
    """)

    execute("""
    CREATE TYPE task_priority AS ENUM ('low', 'normal', 'high', 'critical')
    """)

    execute("""
    CREATE TYPE task_status AS ENUM ('queued', 'processing', 'completed', 'failed')
    """)

    create table(:tasks) do
      add(:title, :string, null: false)
      add(:type, :task_type, null: false)
      add(:priority, :task_priority, default: "normal", null: false)
      add(:payload, :jsonb, null: false)
      add(:max_attempts, :integer, default: 3, null: false)
      add(:status, :task_status, default: "queued", null: false)
      add(:attempts, :jsonb, default: "[]", null: false)

      timestamps()
    end

    create(index(:tasks, [:status]))
    create(index(:tasks, [:type]))
    create(index(:tasks, [:priority]))
    create(index(:tasks, [:inserted_at]))
  end

  def down do
    drop(table(:tasks))

    execute("DROP TYPE task_status")
    execute("DROP TYPE task_priority")
    execute("DROP TYPE task_type")
  end
end
