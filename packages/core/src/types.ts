export type TaskStatus = "todo" | "doing" | "done" | "archived";

export type FocusLevel = "high" | "medium" | "low";
export type Interruptibility = "low" | "medium" | "high";
export type LocationType = "indoor" | "outdoor" | "any";
export type DeviceType = "desktop" | "mobile" | "any";
export type ConcurrencyMode = "serial";
export type Weekday = 1 | 2 | 3 | 4 | 5 | 6 | 7;

export interface TaskTraits {
  focus: FocusLevel;
  interruptibility: Interruptibility;
  location: LocationType;
  device: DeviceType;
  parallelizable: boolean;
}

export interface TaskValueSpec {
  rewardOnTime: number;
  penaltyMissed: number;
}

export interface TaskStepTemplate {
  id: string;
  title: string;
  estimatedMinutes: number;
  minChunkMinutes: number;
  dependsOnStepIds: string[];
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
  scheduleValue: TaskValueSpec;
  dependsOnTaskIds: string[];
  steps: TaskStepTemplate[];
  concurrencyMode: ConcurrencyMode;
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

export interface WeeklyTimeRange {
  id: string;
  weekday: Weekday;
  startTime: string;
  endTime: string;
}

export interface TimeTemplate {
  timezone: string;
  weeklyRanges: WeeklyTimeRange[];
}

export interface PlannedTimeSlot {
  id: string;
  startAt: string;
  endAt: string;
  durationMinutes: number;
}

export interface ScheduleBlock {
  id: string;
  taskId: string;
  stepId?: string | undefined;
  slotId: string;
  startAt: string;
  endAt: string;
  isParallel: boolean;
}

export interface TaskStep {
  id: string;
  taskId: string;
  taskTitle: string;
  title: string;
  estimatedMinutes: number;
  minChunkMinutes: number;
  dueAt?: string | undefined;
  rewardOnTime: number;
  penaltyMissed: number;
  dependsOnStepIds: string[];
  concurrencyMode: ConcurrencyMode;
  source: "task" | "task-step";
  updatedAt: string;
  importance: number;
  legacyValue: number;
}

export interface TaskLink {
  fromStepId: string;
  toStepId: string;
  type: "finish-to-start";
}

export interface TaskGraph {
  steps: TaskStep[];
  links: TaskLink[];
}

export interface OrderedTaskStep {
  stepId: string;
  taskId: string;
  taskTitle: string;
  title: string;
  dueAt?: string | undefined;
  plannedMinutes: number;
  remainingMinutes: number;
  rewardOnTime: number;
  penaltyMissed: number;
  source: "task" | "task-step";
  dependsOnStepIds: string[];
}

export interface ScheduleWarning {
  code: "unscheduled" | "capacity" | "dependency-cycle";
  severity: "warning" | "danger";
  message: string;
  taskId?: string | undefined;
  stepId?: string | undefined;
}

export interface ScheduleView {
  horizonStart: string;
  horizonEnd: string;
  slots: PlannedTimeSlot[];
  blocks: ScheduleBlock[];
  orderedSteps: OrderedTaskStep[];
  unscheduledSteps: OrderedTaskStep[];
  warnings: ScheduleWarning[];
}

export interface ComparatorContext {
  now: string;
  horizonStart: string;
  horizonEnd: string;
}

export interface Comparator {
  compareSteps(a: TaskStep, b: TaskStep, context: ComparatorContext): number;
  scoreCandidate(step: TaskStep, slot: PlannedTimeSlot, context: ComparatorContext): number;
}

export interface LearningEvent {
  id: string;
  higherTaskId: string;
  lowerTaskId: string;
  createdAt: string;
}
