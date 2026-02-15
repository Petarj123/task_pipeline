# TaskPipeline

Asynchronous task processing pipeline using Phoenix, Ecto, and Oban.

## Setup
```bash
mix setup
mix phx.server
```

Server runs at `http://localhost:4000`.

## Environment

See `.tool-versions` for Elixir/Erlang versions.

## API Endpoints

- `POST /api/tasks` - Create task
- `GET /api/tasks` - List tasks (filterable by status, type, priority)
- `GET /api/tasks/:id` - Task details with attempts
- `GET /api/tasks/summary` - Status counts

## Testing
```bash
mix test
```

## Architecture & Decisions

See `NOTES.md` for implementation details and trade-offs.
