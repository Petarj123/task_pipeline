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
