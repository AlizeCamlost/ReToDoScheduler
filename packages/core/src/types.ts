export type TaskStatus = "todo" | "doing" | "done" | "archived";

export type FocusLevel = "high" | "medium" | "low";
export type Interruptibility = "low" | "medium" | "high";
export type LocationType = "indoor" | "outdoor" | "any";
export type DeviceType = "desktop" | "mobile" | "any";

export interface TaskTraits {
  focus: FocusLevel;
  interruptibility: Interruptibility;
  location: LocationType;
  device: DeviceType;
  parallelizable: boolean;
}

export interface Task {
  id: string;
  title: string;
  rawInput: string;
  description?: string | undefined;
  status: TaskStatus;
  estimatedMinutes: number;
  minChunkMinutes: number;
  dueAt?: string | undefined;
  importance: number;
  value: number;
  difficulty: number;
  postponability: number;
  taskTraits: TaskTraits;
  tags: string[];
  createdAt: string;
  updatedAt: string;
  extJson: Record<string, unknown>;
}

export interface TimeSlotTraits {
  focus: FocusLevel;
  interruptibility: Interruptibility;
  location: LocationType;
  device: DeviceType;
  parallelCapacity: 0 | 1;
}

export interface TimeSlot {
  id: string;
  startAt: string;
  endAt: string;
  slotTraits: TimeSlotTraits;
}

export interface ScheduleBlock {
  id: string;
  taskId: string;
  slotId: string;
  startAt: string;
  endAt: string;
  isParallel: boolean;
}

export interface LearningEvent {
  id: string;
  higherTaskId: string;
  lowerTaskId: string;
  createdAt: string;
}
