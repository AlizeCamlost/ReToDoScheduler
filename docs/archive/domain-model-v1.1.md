# Domain Model (v1.1)

## Core entities

- `Task`: main user task with traits and scheduling constraints.
- `TaskPart`: decomposed sub-task for scheduling.
- `TimeWindow`: recurring availability template.
- `TimeSlot`: concrete schedulable interval with slot traits.
- `ScheduleBlock`: assignment of task/task-part into a time slot.
- `LearningEvent`: drag-reorder preference sample.
- `SyncOp`: incremental operation event for cross-device sync.

## Key field notes

- `Task.minChunkMinutes`: minimum acceptable split unit for scheduling.
- `Task.taskTraits`: trait object used for hard/soft slot matching.
- `TimeSlot.slotTraits`: properties of the slot (focus, interruption, location, device).
- `Task.extJson`: extension field for future rules/philosophy dimensions.
> Archived domain draft. The current scheduling truth source is [scheduling-model.md](../scheduling-model.md).
