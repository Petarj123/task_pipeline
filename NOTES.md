## Attempt Tracking

**Decision**: Embedded JSONB array on the task record.

**Rationale**: Simplifies the data model and keeps attempts co-located with their task.

**Pros**:
- Simpler queries - no joins required
- Single row update vs managing foreign key relationships
- Sufficient for the assignment scope (no complex attempt analysis required)

**Cons**:
- Harder to query attempts independently across tasks
- Slower for aggregations like "all failed attempts globally"
- JSONB arrays usually take more storage space than normalized table rows

## Task-Job Synchronization

**Decision**: Wrap task creation and Oban job scheduling in a single transaction.

**Rationale**: The requirement is to enqueue a job as soon as a task is created, therefore tasks without jobs should never exist.

**Alternative approach**: If tasks didn't need to execute immediately, we could register tasks first and bulk schedule them with a separate job. However, that doesn't fit this use case.

## Atomic Task Claiming

**Decision**: Use `Repo.update_all` with `WHERE status = :queued` clause for task claiming.

**Rationale**: Prevents race conditions when multiple workers attempt to claim the same task simultaneously. The database ensures only one worker succeeds.

**Benefits**:
- No pessimistic locking required
- Safe for concurrent workers
- Simple implementation

## Status Transition Validation

**Decision**: Enforce state machine transitions in the `update_changeset` with explicit validation logic.

**Rationale**: Changesets are the clearest and most idiomatic place to enforce business rules in Ecto. The state machine is explicit and easy to understand, all valid transitions are defined in one place with `valid_transition?/2` pattern matching.

**Valid transitions**:
- `queued → processing` (worker claims task)
- `processing → completed` (success)
- `processing → queued` (retry after failure)
- `processing → failed` (max attempts exhausted)

Any other transition is rejected with a clear error message.

## Testing Strategy

**Approach**: Comprehensive test coverage across all layers: schemas, context, worker, and API endpoints.

**What was tested**:
- **Schemas/Changesets**: Valid/invalid data, status transitions, field validations
- **Context functions**: CRUD operations, filtering, sorting, atomic claiming, summary aggregation
- **Oban worker**: Success paths, failure scenarios, retry logic, concurrent claim handling
- **API endpoints**: All routes, validation errors, proper HTTP status codes

**Key techniques**:
- Fixtures for consistent test data setup (`task_fixture`, `raw_task_fixture`)
- Seeded randomness (`:rand.seed`) for deterministic failure simulation in worker tests
- SQL Sandbox for transaction isolation between tests
- `Oban.Testing` for job assertion without actual background processing

**Edge cases covered**:
- Invalid status transitions
- Concurrent task claiming by multiple workers
- Max retry exhaustion
- Invalid filter parameters and malformed IDs
