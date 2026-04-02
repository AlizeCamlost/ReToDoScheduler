import { makeTask, nowIso } from "../defaults";
import { parseQuickInput } from "../nlp";
import type { Task } from "../types";
import { embedTaskBundleMetadata } from "./taskBundle";

export interface TaskSequenceCreationInput {
  title?: string | undefined;
  rawInputs: string[];
  taskIdGenerator: () => string;
  bundleIdGenerator: () => string;
  now?: string | undefined;
}

export const createTasksFromSequence = ({
  title,
  rawInputs,
  taskIdGenerator,
  bundleIdGenerator,
  now = nowIso()
}: TaskSequenceCreationInput): Task[] => {
  const entries = rawInputs
    .map((rawInput) => rawInput.trim())
    .filter((rawInput) => rawInput.length > 0);

  if (entries.length === 0) {
    return [];
  }

  const bundleId = bundleIdGenerator().trim();
  const bundleTitle = title?.trim() || undefined;

  return entries.map((rawInput, index) => {
    const parsed = parseQuickInput(rawInput);

    return makeTask({
      id: taskIdGenerator(),
      title: parsed.title || rawInput,
      rawInput,
      estimatedMinutes: parsed.estimatedMinutes,
      minChunkMinutes: parsed.minChunkMinutes,
      dueAt: parsed.dueAt,
      tags: parsed.tags,
      createdAt: now,
      updatedAt: now,
      extJson: embedTaskBundleMetadata(
        {},
        {
          id: bundleId,
          title: bundleTitle,
          position: index,
          count: entries.length,
          kind: "taskSequence"
        }
      )
    });
  });
};
