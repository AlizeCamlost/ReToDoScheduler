import type { Task } from "../types";
import { getKairosRank } from "../kairos/cursor";

export const sortNornTasks = (tasks: Task[]): Task[] => {
  return [...tasks].sort((a, b) => {
    const rankA = getKairosRank(a);
    const rankB = getKairosRank(b);

    if (rankA !== null && rankB !== null && rankA !== rankB) return rankA - rankB;
    if (rankA !== null && rankB === null) return -1;
    if (rankA === null && rankB !== null) return 1;

    return new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime();
  });
};
