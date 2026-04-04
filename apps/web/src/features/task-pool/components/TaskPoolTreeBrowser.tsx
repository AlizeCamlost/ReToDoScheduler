import {
  getCurrentTaskStep,
  getTaskPoolChildDirectories,
  getTaskPoolDirectory,
  getTaskPoolDirectoryPath,
  getTaskPoolTaskDirectoryId,
  normalizeTaskPoolOrganizationDocument,
  type Task,
  type TaskPoolDirectory,
  type TaskPoolOrganizationDocument
} from "@retodo/core";
import { useEffect, useMemo, useState } from "react";
import TaskBundleBadge from "../../sequence/components/TaskBundleBadge";
import TaskPoolDirectoryModal from "./TaskPoolDirectoryModal";
import TaskPoolMoveModal, { type TaskPoolMoveOption } from "./TaskPoolMoveModal";

interface TaskPoolTreeBrowserProps {
  tasks: Task[];
  organization: TaskPoolOrganizationDocument;
  onOpenTask: (task: Task) => void;
  onCreateDirectory: (name: string, parentDirectoryId?: string) => void;
  onRenameDirectory: (directoryId: string, name: string) => void;
  onDeleteDirectory: (directoryId: string) => void;
  onMoveDirectory: (directoryId: string, parentDirectoryId?: string) => void;
  onMoveTask: (taskId: string, parentDirectoryId?: string) => void;
}

type DirectoryModalState =
  | { mode: "create"; parentDirectoryId?: string }
  | { mode: "rename"; directoryId: string; initialName: string }
  | null;

type MoveModalState =
  | { mode: "directory"; directoryId: string }
  | { mode: "task"; taskId: string }
  | null;

const sortTasks = (tasks: Task[]): Task[] =>
  [...tasks].sort((left, right) => {
    if (left.dueAt && right.dueAt && left.dueAt !== right.dueAt) {
      return left.dueAt.localeCompare(right.dueAt);
    }
    if (left.dueAt && !right.dueAt) return -1;
    if (!left.dueAt && right.dueAt) return 1;
    return left.title.localeCompare(right.title, "zh-CN", { sensitivity: "base" });
  });

export default function TaskPoolTreeBrowser({
  tasks,
  organization,
  onOpenTask,
  onCreateDirectory,
  onRenameDirectory,
  onDeleteDirectory,
  onMoveDirectory,
  onMoveTask
}: TaskPoolTreeBrowserProps) {
  const normalizedOrganization = useMemo(
    () => normalizeTaskPoolOrganizationDocument(organization),
    [organization]
  );
  const taskCountByDirectoryId = useMemo(
    () => buildTaskCountByDirectoryId(tasks, normalizedOrganization),
    [tasks, normalizedOrganization]
  );
  const [selectedDirectoryId, setSelectedDirectoryId] = useState(normalizedOrganization.inboxDirectoryId);
  const [expandedDirectoryIds, setExpandedDirectoryIds] = useState<Set<string>>(
    () => new Set([normalizedOrganization.rootDirectoryId, normalizedOrganization.inboxDirectoryId])
  );
  const [navigationExpanded, setNavigationExpanded] = useState(true);
  const [destinationExpanded, setDestinationExpanded] = useState(true);
  const [directoryModal, setDirectoryModal] = useState<DirectoryModalState>(null);
  const [moveModal, setMoveModal] = useState<MoveModalState>(null);

  useEffect(() => {
    if (!getTaskPoolDirectory(normalizedOrganization, selectedDirectoryId)) {
      setSelectedDirectoryId(normalizedOrganization.inboxDirectoryId);
    }
    setExpandedDirectoryIds((current) => {
      const next = new Set(current);
      next.add(normalizedOrganization.rootDirectoryId);
      next.add(normalizedOrganization.inboxDirectoryId);
      return next;
    });
  }, [normalizedOrganization, selectedDirectoryId]);

  const selectedDirectory =
    getTaskPoolDirectory(normalizedOrganization, selectedDirectoryId) ??
    getTaskPoolDirectory(normalizedOrganization, normalizedOrganization.inboxDirectoryId) ??
    normalizedOrganization.directories[0];

  const selectedPath = selectedDirectory
    ? getTaskPoolDirectoryPath(normalizedOrganization, selectedDirectory.id)
    : [];
  const selectedChildDirectories = selectedDirectory
    ? getTaskPoolChildDirectories(normalizedOrganization, selectedDirectory.id)
    : [];
  const selectedTasks = selectedDirectory
    ? sortTasks(tasks.filter((task) => getTaskPoolTaskDirectoryId(normalizedOrganization, task.id) === selectedDirectory.id))
    : [];

  const allDirectoryOptions = useMemo<TaskPoolMoveOption[]>(
    () =>
      normalizedOrganization.directories.map((directory) => ({
        id: directory.id,
        label: formatDirectoryPath(normalizedOrganization, directory.id)
      })),
    [normalizedOrganization]
  );

  const moveOptions = useMemo<TaskPoolMoveOption[]>(() => {
    if (!moveModal) return [];

    if (moveModal.mode === "task") {
      const currentDirectoryId = getTaskPoolTaskDirectoryId(normalizedOrganization, moveModal.taskId);
      return allDirectoryOptions.filter((option) => option.id !== currentDirectoryId);
    }

    const invalidParentIds = new Set([
      moveModal.directoryId,
      ...collectDescendantDirectoryIds(normalizedOrganization, moveModal.directoryId)
    ]);
    const movingDirectory = getTaskPoolDirectory(normalizedOrganization, moveModal.directoryId);

    return allDirectoryOptions.filter(
      (option) =>
        option.id !== normalizedOrganization.inboxDirectoryId &&
        !invalidParentIds.has(option.id) &&
        option.id !== movingDirectory?.parentDirectoryId
    );
  }, [allDirectoryOptions, moveModal, normalizedOrganization]);

  const initialMoveTargetId = useMemo(() => {
    if (!moveModal || moveOptions.length === 0) return "";

    if (moveModal.mode === "task") {
      return moveOptions[0]?.id ?? "";
    }

    const directory = getTaskPoolDirectory(normalizedOrganization, moveModal.directoryId);
    return moveOptions.find((option) => option.id === directory?.parentDirectoryId)?.id ?? moveOptions[0]?.id ?? "";
  }, [moveModal, moveOptions, normalizedOrganization]);

  const selectDirectory = (directoryId: string) => {
    setSelectedDirectoryId(directoryId);
    const path = getTaskPoolDirectoryPath(normalizedOrganization, directoryId);
    setExpandedDirectoryIds((current) => {
      const next = new Set(current);
      path.forEach((directory) => next.add(directory.id));
      return next;
    });
  };

  const canEditDirectory = (directory: TaskPoolDirectory | undefined): boolean =>
    Boolean(
      directory &&
        directory.id !== normalizedOrganization.rootDirectoryId &&
        directory.id !== normalizedOrganization.inboxDirectoryId
    );

  return (
    <>
      <div className="task-pool-tree-browser">
        <section className="task-pool-section-card">
          <div className="task-pool-section-head">
            <div>
              <div className="task-pool-section-kicker">目录</div>
              <div className="task-pool-section-title">
                已选 {selectedDirectory ? displayDirectoryName(normalizedOrganization, selectedDirectory) : "待整理"}
              </div>
            </div>
            <button className="btn-icon subtle" onClick={() => setNavigationExpanded((current) => !current)} title={navigationExpanded ? "收起目录" : "展开目录"}>
              {navigationExpanded ? "⌃" : "⌄"}
            </button>
          </div>

          {navigationExpanded && (
            <div className="task-pool-tree-nav">
              {renderDirectoryNode({
                directory:
                  getTaskPoolDirectory(normalizedOrganization, normalizedOrganization.rootDirectoryId) ??
                  normalizedOrganization.directories[0]!,
                depth: 0,
                organization: normalizedOrganization,
                selectedDirectoryId,
                expandedDirectoryIds,
                taskCountByDirectoryId,
                onSelect: selectDirectory,
                onToggleExpanded: (directoryId) =>
                  setExpandedDirectoryIds((current) => {
                    const next = new Set(current);
                    if (next.has(directoryId)) {
                      next.delete(directoryId);
                    } else {
                      next.add(directoryId);
                    }
                    return next;
                  })
              })}
            </div>
          )}
        </section>

        <section className="task-pool-section-card">
          <div className="task-pool-section-head">
            <div>
              <div className="task-pool-section-kicker">目的地</div>
              <div className="task-pool-section-title">
                {selectedDirectory ? displayDirectoryName(normalizedOrganization, selectedDirectory) : "待整理"}
              </div>
              <div className="task-pool-directory-path">
                {selectedPath.map((directory) => displayDirectoryName(normalizedOrganization, directory)).join(" / ")}
              </div>
            </div>

            <div className="task-pool-destination-actions">
              <button
                className="btn-icon subtle"
                onClick={() => setDestinationExpanded((current) => !current)}
                title={destinationExpanded ? "收起目的地" : "展开目的地"}
              >
                {destinationExpanded ? "⌃" : "⌄"}
              </button>
              <button
                className="btn-text"
                onClick={() =>
                  setDirectoryModal({
                    mode: "create",
                    ...(selectedDirectory?.id ? { parentDirectoryId: selectedDirectory.id } : {})
                  })
                }
              >
                新建子目录
              </button>
              {canEditDirectory(selectedDirectory) && (
                <>
                  <button
                    className="btn-text"
                    onClick={() =>
                      selectedDirectory &&
                      setDirectoryModal({
                        mode: "rename",
                        directoryId: selectedDirectory.id,
                        initialName: selectedDirectory.name
                      })
                    }
                  >
                    重命名
                  </button>
                  <button className="btn-text" onClick={() => selectedDirectory && setMoveModal({ mode: "directory", directoryId: selectedDirectory.id })}>
                    移动
                  </button>
                  <button
                    className="btn-text danger-text"
                    onClick={() => {
                      if (selectedDirectory && window.confirm("删除这个目录？子目录和任务会回收到待整理。")) {
                        onDeleteDirectory(selectedDirectory.id);
                      }
                    }}
                  >
                    删除
                  </button>
                </>
              )}
            </div>
          </div>

          {destinationExpanded && (
            <>
              {(selectedChildDirectories.length > 0 || selectedDirectory?.parentDirectoryId) && (
                <div className="task-pool-destination-list">
                  {selectedDirectory?.parentDirectoryId && (
                    <button
                      className="task-pool-directory-chip back"
                      onClick={() => selectDirectory(selectedDirectory.parentDirectoryId!)}
                    >
                      <span>..</span>
                      <span>{displayDirectoryName(normalizedOrganization, getTaskPoolDirectory(normalizedOrganization, selectedDirectory.parentDirectoryId!)!)}</span>
                    </button>
                  )}

                  {selectedChildDirectories.map((directory) => (
                    <button key={directory.id} className="task-pool-directory-chip" onClick={() => selectDirectory(directory.id)}>
                      <span>{displayDirectoryName(normalizedOrganization, directory)}</span>
                      <span>{countTasksInDirectory(tasks, normalizedOrganization, directory.id)} 项</span>
                    </button>
                  ))}
                </div>
              )}

              <div className="task-pool-destination-block">
                <div className="task-pool-block-title">任务</div>
                {selectedTasks.length === 0 ? (
                  <div className="empty-panel">暂无任务</div>
                ) : (
                  <div className="task-pool-task-list">
                    {selectedTasks.map((task) => {
                      const currentStep = getCurrentTaskStep(task);
                      return (
                        <div key={task.id} className="task-pool-task-card">
                          <button className="task-pool-task-main" onClick={() => onOpenTask(task)}>
                            <div className="task-pool-task-title-row">
                              <div className="task-pool-task-title">{task.title}</div>
                              <span className={`status-pill status-${task.status}`}>{task.status}</span>
                            </div>
                            <div className="task-pool-task-meta">
                              {task.dueAt ? `截止 ${new Date(task.dueAt).toLocaleDateString("zh-CN")}` : "未设截止"}
                              <span>估时 {task.estimatedMinutes} 分钟</span>
                            </div>
                            <TaskBundleBadge task={task} />
                            {currentStep && (
                              <div className="task-pool-task-step">
                                当前步骤 {task.steps.findIndex((step) => step.id === currentStep.id) + 1}/{task.steps.length} · {currentStep.title}
                              </div>
                            )}
                          </button>

                          <div className="task-pool-task-actions">
                            {selectedDirectory?.id !== normalizedOrganization.inboxDirectoryId && (
                              <button
                                className="btn-text"
                                onClick={() => onMoveTask(task.id, normalizedOrganization.inboxDirectoryId)}
                              >
                                归位待整理
                              </button>
                            )}
                            <button className="btn-text" onClick={() => setMoveModal({ mode: "task", taskId: task.id })}>
                              移动
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </>
          )}
        </section>
      </div>

      {directoryModal && (
        <TaskPoolDirectoryModal
          title={directoryModal.mode === "create" ? "新建目录" : "重命名目录"}
          initialName={directoryModal.mode === "rename" ? directoryModal.initialName : ""}
          submitLabel={directoryModal.mode === "create" ? "创建" : "保存"}
          onSubmit={(name) => {
            if (directoryModal.mode === "create") {
              onCreateDirectory(name, directoryModal.parentDirectoryId);
            } else {
              onRenameDirectory(directoryModal.directoryId, name);
            }
            setDirectoryModal(null);
          }}
          onClose={() => setDirectoryModal(null)}
        />
      )}

      {moveModal && moveOptions.length > 0 && (
        <TaskPoolMoveModal
          title={moveModal.mode === "directory" ? "移动目录" : "移动任务"}
          options={moveOptions}
          initialTargetId={initialMoveTargetId}
          submitLabel="移动"
          onSubmit={(targetId) => {
            if (moveModal.mode === "directory") {
              onMoveDirectory(moveModal.directoryId, targetId);
            } else {
              onMoveTask(moveModal.taskId, targetId);
            }
            setMoveModal(null);
          }}
          onClose={() => setMoveModal(null)}
        />
      )}
    </>
  );
}

interface RenderDirectoryNodeArgs {
  directory: TaskPoolDirectory;
  depth: number;
  organization: TaskPoolOrganizationDocument;
  selectedDirectoryId: string;
  expandedDirectoryIds: Set<string>;
  taskCountByDirectoryId: Map<string, number>;
  onSelect: (directoryId: string) => void;
  onToggleExpanded: (directoryId: string) => void;
}

const renderDirectoryNode = ({
  directory,
  depth,
  organization,
  selectedDirectoryId,
  expandedDirectoryIds,
  taskCountByDirectoryId,
  onSelect,
  onToggleExpanded
}: RenderDirectoryNodeArgs): JSX.Element => {
  const childDirectories = getTaskPoolChildDirectories(organization, directory.id);
  const expanded = expandedDirectoryIds.has(directory.id);

  return (
    <div key={directory.id} className="task-pool-directory-node">
      <div
        className={`task-pool-directory-row${selectedDirectoryId === directory.id ? " selected" : ""}`}
        style={{ paddingLeft: `${depth * 18}px` }}
      >
        {childDirectories.length > 0 ? (
          <button className="task-pool-directory-toggle" onClick={() => onToggleExpanded(directory.id)}>
            {expanded ? "⌄" : "›"}
          </button>
        ) : (
          <span className="task-pool-directory-spacer" />
        )}

        <button className="task-pool-directory-select" onClick={() => onSelect(directory.id)}>
          <span className="task-pool-directory-name">{displayDirectoryName(organization, directory)}</span>
          <span className="task-pool-directory-count">{taskCountByDirectoryId.get(directory.id) ?? 0}</span>
        </button>
      </div>

      {expanded &&
        childDirectories.map((childDirectory) =>
          renderDirectoryNode({
            directory: childDirectory,
            depth: depth + 1,
            organization,
            selectedDirectoryId,
            expandedDirectoryIds,
            taskCountByDirectoryId,
            onSelect,
            onToggleExpanded
          })
        )}
    </div>
  );
};

const buildTaskCountByDirectoryId = (
  tasks: Task[],
  organization: TaskPoolOrganizationDocument
): Map<string, number> => {
  const counts = new Map<string, number>();
  for (const task of tasks) {
    const directoryId = getTaskPoolTaskDirectoryId(organization, task.id);
    counts.set(directoryId, (counts.get(directoryId) ?? 0) + 1);
  }
  return counts;
};

const countTasksInDirectory = (
  tasks: Task[],
  organization: TaskPoolOrganizationDocument,
  directoryId: string
): number => tasks.filter((task) => getTaskPoolTaskDirectoryId(organization, task.id) === directoryId).length;

const collectDescendantDirectoryIds = (
  organization: TaskPoolOrganizationDocument,
  directoryId: string
): string[] => {
  const children = getTaskPoolChildDirectories(organization, directoryId);
  return children.flatMap((child) => [child.id, ...collectDescendantDirectoryIds(organization, child.id)]);
};

const displayDirectoryName = (
  organization: TaskPoolOrganizationDocument,
  directory: TaskPoolDirectory
): string => {
  if (directory.id === organization.rootDirectoryId) return "全部任务";
  if (directory.id === organization.inboxDirectoryId) return "待整理";
  return directory.name;
};

const formatDirectoryPath = (
  organization: TaskPoolOrganizationDocument,
  directoryId: string
): string =>
  getTaskPoolDirectoryPath(organization, directoryId)
    .map((directory) => displayDirectoryName(organization, directory))
    .join(" / ");
