import { type Task, type TaskPoolOrganizationDocument } from "@retodo/core";
import { useState } from "react";
import TaskPoolCanvasView from "./TaskPoolCanvasView";
import TaskPoolTreeBrowser from "./TaskPoolTreeBrowser";

interface TaskPoolPanelProps {
  tasks: Task[];
  organization: TaskPoolOrganizationDocument;
  syncMessage: string;
  isSyncing: boolean;
  onRefresh: () => void;
  onOpenSettings: () => void;
  onExport: () => void;
  onImport: (file: File | null) => Promise<void>;
  onOpenTask: (task: Task) => void;
  onCreateDirectory: (name: string, parentDirectoryId?: string) => void;
  onRenameDirectory: (directoryId: string, name: string) => void;
  onDeleteDirectory: (directoryId: string) => void;
  onMoveDirectory: (directoryId: string, parentDirectoryId?: string) => void;
  onPlaceTask: (taskId: string, parentDirectoryId?: string) => void;
  onUpdateCanvasNode: (
    nodeId: string,
    nodeKind: "directory" | "task",
    x: number,
    y: number,
    isCollapsed: boolean
  ) => void;
  onResetCanvasLayout: (positionsByStableId: Record<string, { x: number; y: number }>) => void;
}

type TaskPoolViewMode = "tree" | "canvas";

export default function TaskPoolPanel({
  tasks,
  organization,
  syncMessage,
  isSyncing,
  onRefresh,
  onOpenSettings,
  onExport,
  onImport,
  onOpenTask,
  onCreateDirectory,
  onRenameDirectory,
  onDeleteDirectory,
  onMoveDirectory,
  onPlaceTask,
  onUpdateCanvasNode,
  onResetCanvasLayout
}: TaskPoolPanelProps) {
  const [viewMode, setViewMode] = useState<TaskPoolViewMode>("tree");

  return (
    <section className="card task-pool-panel">
      <div className="panel-header">
        <div className="panel-title">任务池</div>
        <div
          className={`inline-sync-status ${isSyncing ? "syncing" : syncMessage.startsWith("同步失败") || syncMessage.startsWith("拉取失败") ? "error" : ""}`}
        >
          {syncMessage}
        </div>
      </div>

      <div className="task-pool-toolbar">
        <div className="filter-tabs">
          <button className={`filter-tab${viewMode === "tree" ? " active" : ""}`} onClick={() => setViewMode("tree")}>
            目录
          </button>
          <button className={`filter-tab${viewMode === "canvas" ? " active" : ""}`} onClick={() => setViewMode("canvas")}>
            脑图
          </button>
        </div>

        <div className="toolbar compact-toolbar">
          <button className="btn-text" onClick={onRefresh} disabled={isSyncing}>
            {isSyncing ? "同步中" : "刷新"}
          </button>
          <button className="btn-text" onClick={onOpenSettings}>
            设置
          </button>
          <button className="btn-text" onClick={onExport}>
            导出
          </button>
          <label className="file-label">
            导入
            <input
              type="file"
              accept=".md,text/markdown"
              onChange={(event) => void onImport(event.target.files?.[0] ?? null)}
            />
          </label>
        </div>
      </div>

      {viewMode === "tree" ? (
        <TaskPoolTreeBrowser
          tasks={tasks}
          organization={organization}
          onOpenTask={onOpenTask}
          onCreateDirectory={onCreateDirectory}
          onRenameDirectory={onRenameDirectory}
          onDeleteDirectory={onDeleteDirectory}
          onMoveDirectory={onMoveDirectory}
          onMoveTask={onPlaceTask}
        />
      ) : (
        <TaskPoolCanvasView
          tasks={tasks}
          organization={organization}
          onOpenTask={onOpenTask}
          onUpdateNode={onUpdateCanvasNode}
          onResetLayout={onResetCanvasLayout}
        />
      )}
    </section>
  );
}
