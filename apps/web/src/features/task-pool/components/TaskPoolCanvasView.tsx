import {
  getCurrentTaskStep,
  getTaskBundleMetadata,
  getTaskPoolCanvasStableId,
  getTaskPoolChildDirectories,
  getTaskPoolDirectory,
  getTaskPoolDirectoryPath,
  getTaskPoolTaskDirectoryId,
  normalizeTaskPoolOrganizationDocument,
  type Task,
  type TaskPoolOrganizationDocument
} from "@retodo/core";
import { useMemo, useState, type PointerEvent as ReactPointerEvent } from "react";

interface TaskPoolCanvasViewProps {
  tasks: Task[];
  organization: TaskPoolOrganizationDocument;
  onOpenTask: (task: Task) => void;
  onUpdateNode: (
    nodeId: string,
    nodeKind: "directory" | "task",
    x: number,
    y: number,
    isCollapsed: boolean
  ) => void;
  onResetLayout: (positionsByStableId: Record<string, { x: number; y: number }>) => void;
}

interface CanvasNode {
  stableId: string;
  nodeId: string;
  nodeKind: "directory" | "task";
  label: string;
  secondary: string;
  status?: Task["status"];
  position: { x: number; y: number };
  width: number;
  height: number;
  isCollapsed: boolean;
  hasChildren: boolean;
  parentStableId?: string;
  task?: Task;
}

interface DragState {
  stableId: string;
  nodeId: string;
  nodeKind: "directory" | "task";
  pointerId: number;
  startClientX: number;
  startClientY: number;
  startX: number;
  startY: number;
  isCollapsed: boolean;
}

const DIRECTORY_NODE_WIDTH = 208;
const DIRECTORY_NODE_HEIGHT = 92;
const TASK_NODE_WIDTH = 244;
const TASK_NODE_HEIGHT = 122;
const COLUMN_GAP = 320;
const TASK_OFFSET_X = 214;
const ROW_GAP = 140;
const CANVAS_PADDING = 88;

const sortTasks = (tasks: Task[]): Task[] =>
  [...tasks].sort((left, right) => {
    if (left.dueAt && right.dueAt && left.dueAt !== right.dueAt) {
      return left.dueAt.localeCompare(right.dueAt);
    }
    if (left.dueAt && !right.dueAt) return -1;
    if (!left.dueAt && right.dueAt) return 1;
    return left.title.localeCompare(right.title, "zh-CN", { sensitivity: "base" });
  });

export default function TaskPoolCanvasView({
  tasks,
  organization,
  onOpenTask,
  onUpdateNode,
  onResetLayout
}: TaskPoolCanvasViewProps) {
  const normalizedOrganization = useMemo(
    () => normalizeTaskPoolOrganizationDocument(organization),
    [organization]
  );
  const [zoom, setZoom] = useState(1);
  const [dragState, setDragState] = useState<DragState | null>(null);
  const [draftPositions, setDraftPositions] = useState<Record<string, { x: number; y: number }>>({});

  const layout = useMemo(
    () => buildCanvasLayout(normalizedOrganization, tasks),
    [normalizedOrganization, tasks]
  );

  const currentNodes = useMemo<CanvasNode[]>(
    () =>
      layout.nodes
        .filter((node) => isNodeVisible(node, normalizedOrganization))
        .map((node) => ({
          ...node,
          position: draftPositions[node.stableId] ?? node.position
        })),
    [draftPositions, layout.nodes, normalizedOrganization]
  );

  const nodeByStableId = useMemo(
    () => new Map(currentNodes.map((node) => [node.stableId, node])),
    [currentNodes]
  );

  const edges = useMemo(
    () =>
      currentNodes.flatMap((node) => {
        if (!node.parentStableId) return [];
        const parent = nodeByStableId.get(node.parentStableId);
        if (!parent) return [];
        return [
          {
            id: `${node.parentStableId}->${node.stableId}`,
            startX: parent.position.x + parent.width,
            startY: parent.position.y + parent.height / 2,
            endX: node.position.x,
            endY: node.position.y + node.height / 2
          }
        ];
      }),
    [currentNodes, nodeByStableId]
  );

  const bounds = useMemo(() => {
    const logicalWidth =
      currentNodes.length === 0
        ? 1200
        : Math.max(...currentNodes.map((node) => node.position.x + node.width)) + CANVAS_PADDING;
    const logicalHeight =
      currentNodes.length === 0
        ? 720
        : Math.max(...currentNodes.map((node) => node.position.y + node.height)) + CANVAS_PADDING;

    return {
      logicalWidth,
      logicalHeight,
      viewportWidth: logicalWidth * zoom,
      viewportHeight: logicalHeight * zoom
    };
  }, [currentNodes, zoom]);

  const handlePointerDown = (event: ReactPointerEvent<HTMLDivElement>, node: CanvasNode) => {
    if (event.button !== 0) return;

    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    setDragState({
      stableId: node.stableId,
      nodeId: node.nodeId,
      nodeKind: node.nodeKind,
      pointerId: event.pointerId,
      startClientX: event.clientX,
      startClientY: event.clientY,
      startX: node.position.x,
      startY: node.position.y,
      isCollapsed: node.isCollapsed
    });
  };

  const handlePointerMove = (event: ReactPointerEvent<HTMLDivElement>, node: CanvasNode) => {
    if (
      !dragState ||
      dragState.pointerId !== event.pointerId ||
      dragState.stableId !== node.stableId
    ) {
      return;
    }

    const deltaX = (event.clientX - dragState.startClientX) / zoom;
    const deltaY = (event.clientY - dragState.startClientY) / zoom;

    setDraftPositions((current) => ({
      ...current,
      [node.stableId]: {
        x: Math.max(24, dragState.startX + deltaX),
        y: Math.max(24, dragState.startY + deltaY)
      }
    }));
  };

  const finishDrag = (
    event: ReactPointerEvent<HTMLDivElement>,
    node: CanvasNode,
    cancelled: boolean
  ) => {
    if (
      !dragState ||
      dragState.pointerId !== event.pointerId ||
      dragState.stableId !== node.stableId
    ) {
      return;
    }

    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }

    const nextPosition = draftPositions[node.stableId] ?? {
      x: dragState.startX,
      y: dragState.startY
    };

    setDragState(null);
    setDraftPositions((current) => {
      const next = { ...current };
      delete next[node.stableId];
      return next;
    });

    if (cancelled) return;

    onUpdateNode(
      dragState.nodeId,
      dragState.nodeKind,
      nextPosition.x,
      nextPosition.y,
      dragState.isCollapsed
    );
  };

  const handleResetLayout = () => {
    setDraftPositions({});
    setDragState(null);
    setZoom(1);
    onResetLayout(layout.defaultPositionsByStableId);
  };

  return (
    <section className="task-pool-canvas-shell">
      <div className="task-pool-canvas-toolbar">
        <div className="task-pool-section-kicker">脑图</div>

        <div className="task-pool-canvas-controls">
          <button className="btn-icon subtle" onClick={() => setZoom((current) => Math.max(0.7, current - 0.1))} title="缩小">
            −
          </button>
          <button className="btn-text" onClick={() => setZoom(1)}>
            {Math.round(zoom * 100)}%
          </button>
          <button className="btn-icon subtle" onClick={() => setZoom((current) => Math.min(1.5, current + 0.1))} title="放大">
            +
          </button>
          <button className="btn-text" onClick={handleResetLayout}>
            重置布局
          </button>
        </div>
      </div>

      <div className="task-pool-canvas-scroller">
        <div
          className="task-pool-canvas-viewport"
          style={{ width: `${bounds.viewportWidth}px`, height: `${bounds.viewportHeight}px` }}
        >
          <div
            className="task-pool-canvas-stage"
            style={{
              width: `${bounds.logicalWidth}px`,
              height: `${bounds.logicalHeight}px`,
              transform: `scale(${zoom})`,
              transformOrigin: "top left"
            }}
          >
            <svg
              className="task-pool-canvas-edges"
              width={bounds.logicalWidth}
              height={bounds.logicalHeight}
              viewBox={`0 0 ${bounds.logicalWidth} ${bounds.logicalHeight}`}
              aria-hidden="true"
            >
              {edges.map((edge) => (
                <path
                  key={edge.id}
                  className="task-pool-canvas-edge"
                  d={`M ${edge.startX} ${edge.startY} C ${edge.startX + 52} ${edge.startY}, ${edge.endX - 52} ${edge.endY}, ${edge.endX} ${edge.endY}`}
                />
              ))}
            </svg>

            {currentNodes.map((node) => {
              const currentStep = node.task ? getCurrentTaskStep(node.task) : null;
              const bundleMetadata = node.task ? getTaskBundleMetadata(node.task) : null;

              return (
                <div
                  key={node.stableId}
                  className={`task-pool-canvas-node ${node.nodeKind} ${node.status ? `status-${node.status}` : ""} ${dragState?.stableId === node.stableId ? "dragging" : ""}`}
                  style={{
                    width: `${node.width}px`,
                    minHeight: `${node.height}px`,
                    transform: `translate(${node.position.x}px, ${node.position.y}px)`
                  }}
                >
                  <div
                    className="task-pool-canvas-node-handle"
                    onPointerDown={(event) => handlePointerDown(event, node)}
                    onPointerMove={(event) => handlePointerMove(event, node)}
                    onPointerUp={(event) => finishDrag(event, node, false)}
                    onPointerCancel={(event) => finishDrag(event, node, true)}
                  >
                    <div className="task-pool-canvas-node-title">{node.label}</div>
                    {node.nodeKind === "directory" && (
                      <button
                        className="btn-icon subtle task-pool-canvas-collapse"
                        onPointerDown={(event) => event.stopPropagation()}
                        onClick={() =>
                          onUpdateNode(
                            node.nodeId,
                            "directory",
                            node.position.x,
                            node.position.y,
                            !node.isCollapsed
                          )
                        }
                        disabled={!node.hasChildren}
                        title={node.isCollapsed ? "展开目录" : "折叠目录"}
                      >
                        {node.isCollapsed ? "⊞" : "⊟"}
                      </button>
                    )}
                  </div>

                  {node.nodeKind === "directory" ? (
                    <div className="task-pool-canvas-node-body">
                      <div className="task-pool-canvas-node-secondary">{node.secondary}</div>
                      {node.hasChildren && node.isCollapsed && <div className="canvas-node-meta">已折叠</div>}
                    </div>
                  ) : (
                    <button className="task-pool-canvas-card" onClick={() => node.task && onOpenTask(node.task)}>
                      <div className="task-pool-canvas-task-topline">
                        <span className={`status-pill status-${node.status}`}>{node.status}</span>
                        <span className="task-pool-canvas-node-secondary">{node.secondary}</span>
                      </div>
                      {bundleMetadata && (
                        <div className="task-pool-canvas-bundle">
                          {bundleMetadata.title ?? "任务序列"} {bundleMetadata.position + 1}/{bundleMetadata.count}
                        </div>
                      )}
                      {currentStep && (
                        <div className="canvas-node-meta">
                          当前步骤 {node.task!.steps.findIndex((step) => step.id === currentStep.id) + 1}/{node.task!.steps.length} · {currentStep.title}
                        </div>
                      )}
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}

const buildCanvasLayout = (
  organization: TaskPoolOrganizationDocument,
  tasks: Task[]
): {
  nodes: CanvasNode[];
  defaultPositionsByStableId: Record<string, { x: number; y: number }>;
} => {
  const normalizedOrganization = normalizeTaskPoolOrganizationDocument(organization);
  const taskLayoutsByStableId = new Map(
    normalizedOrganization.canvasNodes.map((node) => [
      getTaskPoolCanvasStableId(node.nodeKind, node.nodeId),
      node
    ])
  );
  const tasksByDirectoryId = new Map<string, Task[]>();
  const sortedTasks = sortTasks(tasks);

  for (const task of sortedTasks) {
    const directoryId = getTaskPoolTaskDirectoryId(normalizedOrganization, task.id);
    const bucket = tasksByDirectoryId.get(directoryId) ?? [];
    bucket.push(task);
    tasksByDirectoryId.set(directoryId, bucket);
  }

  let row = 0;
  const nodes: CanvasNode[] = [];
  const defaultPositionsByStableId: Record<string, { x: number; y: number }> = {};

  const visitDirectory = (directoryId: string, depth: number) => {
    const directory = getTaskPoolDirectory(normalizedOrganization, directoryId);
    if (!directory) return;

    const stableId = getTaskPoolCanvasStableId("directory", directory.id);
    const defaultPosition = {
      x: 36 + depth * COLUMN_GAP,
      y: 36 + row * ROW_GAP
    };
    const storedLayout = taskLayoutsByStableId.get(stableId);
    const childDirectories = getTaskPoolChildDirectories(normalizedOrganization, directory.id);
    const directoryTasks = tasksByDirectoryId.get(directory.id) ?? [];

    defaultPositionsByStableId[stableId] = defaultPosition;
    nodes.push({
      stableId,
      nodeId: directory.id,
      nodeKind: "directory",
      label: displayDirectoryName(normalizedOrganization, directory.id),
      secondary: formatDirectoryPath(normalizedOrganization, directory.id),
      position: storedLayout ? { x: storedLayout.x, y: storedLayout.y } : defaultPosition,
      width: DIRECTORY_NODE_WIDTH,
      height: DIRECTORY_NODE_HEIGHT,
      isCollapsed: storedLayout?.isCollapsed ?? false,
      hasChildren: childDirectories.length > 0 || directoryTasks.length > 0,
      ...(directory.parentDirectoryId
        ? {
            parentStableId: getTaskPoolCanvasStableId("directory", directory.parentDirectoryId)
          }
        : {})
    });
    row += 1;

    for (const childDirectory of childDirectories) {
      visitDirectory(childDirectory.id, depth + 1);
    }

    for (const task of directoryTasks) {
      const taskStableId = getTaskPoolCanvasStableId("task", task.id);
      const defaultTaskPosition = {
        x: 36 + depth * COLUMN_GAP + TASK_OFFSET_X,
        y: 36 + row * ROW_GAP
      };
      const storedTaskLayout = taskLayoutsByStableId.get(taskStableId);
      const currentStep = getCurrentTaskStep(task);

      defaultPositionsByStableId[taskStableId] = defaultTaskPosition;
      nodes.push({
        stableId: taskStableId,
        nodeId: task.id,
        nodeKind: "task",
        label: task.title,
        secondary: task.dueAt ? formatDueLabel(task.dueAt) : `估时 ${task.estimatedMinutes} 分钟`,
        status: task.status,
        position: storedTaskLayout ? { x: storedTaskLayout.x, y: storedTaskLayout.y } : defaultTaskPosition,
        width: TASK_NODE_WIDTH,
        height: currentStep ? TASK_NODE_HEIGHT + 16 : TASK_NODE_HEIGHT,
        isCollapsed: false,
        hasChildren: false,
        parentStableId: stableId,
        task
      });
      row += 1;
    }
  };

  visitDirectory(normalizedOrganization.rootDirectoryId, 0);

  return { nodes, defaultPositionsByStableId };
};

const isNodeVisible = (
  node: CanvasNode,
  organization: TaskPoolOrganizationDocument
): boolean => {
  const normalizedOrganization = normalizeTaskPoolOrganizationDocument(organization);

  if (node.nodeKind === "directory") {
    const path = getTaskPoolDirectoryPath(normalizedOrganization, node.nodeId);
    return path.slice(0, -1).every((directory) => !isDirectoryCollapsed(normalizedOrganization, directory.id));
  }

  const parentDirectoryId = getTaskPoolTaskDirectoryId(normalizedOrganization, node.nodeId);
  const path = getTaskPoolDirectoryPath(normalizedOrganization, parentDirectoryId);
  return path.every((directory) => !isDirectoryCollapsed(normalizedOrganization, directory.id));
};

const isDirectoryCollapsed = (
  organization: TaskPoolOrganizationDocument,
  directoryId: string
): boolean =>
  normalizeTaskPoolOrganizationDocument(organization).canvasNodes.some(
    (node) => node.nodeKind === "directory" && node.nodeId === directoryId && node.isCollapsed
  );

const displayDirectoryName = (
  organization: TaskPoolOrganizationDocument,
  directoryId: string
): string => {
  if (directoryId === organization.rootDirectoryId) return "全部任务";
  if (directoryId === organization.inboxDirectoryId) return "待整理";
  return getTaskPoolDirectory(organization, directoryId)?.name ?? "未命名目录";
};

const formatDirectoryPath = (
  organization: TaskPoolOrganizationDocument,
  directoryId: string
): string =>
  getTaskPoolDirectoryPath(organization, directoryId)
    .map((directory) => displayDirectoryName(organization, directory.id))
    .join(" / ");

const formatDueLabel = (dueAt: string): string => {
  const dueDate = new Date(dueAt);
  return `截止 ${dueDate.toLocaleDateString("zh-CN")}`;
};
