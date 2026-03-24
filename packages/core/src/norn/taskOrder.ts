import type { Task } from "../types";
import { getKairosRank } from "../kairos/cursor";

const readExt = (task: Task): Record<string, unknown> =>
  typeof task.extJson === "object" && task.extJson ? task.extJson : {};

const isSequencedTask = (task: Task): boolean => task.status === "todo" || task.status === "doing";

export const getNornSequenceRank = (task: Task): number | null => {
  if (!isSequencedTask(task)) return null;

  const ext = readExt(task);
  const norn = ext.norn;
  if (!norn || typeof norn !== "object") return null;

  const rank = (norn as Record<string, unknown>).sequenceRank;
  return typeof rank === "number" ? rank : null;
};

export const withNornSequenceRank = (task: Task, rank: number | null): Task => {
  const ext = readExt(task);
  const norn =
    ext.norn && typeof ext.norn === "object"
      ? { ...(ext.norn as Record<string, unknown>) }
      : {};

  if (rank === null) {
    delete norn.sequenceRank;
  } else {
    norn.sequenceRank = rank;
  }

  const nextExt = { ...ext };
  if (Object.keys(norn).length === 0) {
    delete nextExt.norn;
  } else {
    nextExt.norn = norn;
  }

  return {
    ...task,
    extJson: nextExt
  };
};

export const sortNornTasks = (tasks: Task[]): Task[] => {
  return [...tasks].sort((a, b) => {
    const sequenceRankA = getNornSequenceRank(a);
    const sequenceRankB = getNornSequenceRank(b);

    if (sequenceRankA !== null && sequenceRankB !== null && sequenceRankA !== sequenceRankB) return sequenceRankA - sequenceRankB;
    if (sequenceRankA !== null && sequenceRankB === null) return -1;
    if (sequenceRankA === null && sequenceRankB !== null) return 1;

    const rankA = getKairosRank(a);
    const rankB = getKairosRank(b);

    if (rankA !== null && rankB !== null && rankA !== rankB) return rankA - rankB;
    if (rankA !== null && rankB === null) return -1;
    if (rankA === null && rankB !== null) return 1;

    return new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime();
  });
};
