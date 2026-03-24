import type { Task } from "@retodo/core";
import { useState } from "react";
import TaskItem from "./TaskItem";

interface TaskPoolPanelProps {
  tasks: Task[];
  searchQuery: string;
  onSearchQueryChange: (value: string) => void;
  onToggleDone: (taskId: string) => void;
  onArchive: (taskId: string) => void;
  syncMessage: string;
  isSyncing: boolean;
  onRefresh: () => void;
  onExport: () => void;
  onImport: (file: File | null) => Promise<void>;
  onOpenDetail: (task: Task) => void;
  onEdit: (task: Task) => void;
}

export default function TaskPoolPanel({
  tasks,
  searchQuery,
  onSearchQueryChange,
  onToggleDone,
  onArchive,
  syncMessage,
  isSyncing,
  onRefresh,
  onExport,
  onImport,
  onOpenDetail,
  onEdit
}: TaskPoolPanelProps) {
  const [viewMode, setViewMode] = useState<"list" | "quadrant" | "cluster">("list");

  return (
    <section className="card">
      <div className="panel-header">
        <div>
          <div className="panel-title">任务池</div>
          <div className="panel-caption">任务、依赖、子步骤都在这里维护。</div>
        </div>
        <div className={`inline-sync-status ${isSyncing ? "syncing" : syncMessage.startsWith("同步失败") || syncMessage.startsWith("拉取失败") ? "error" : ""}`}>
          {syncMessage}
        </div>
      </div>

      <div className="panel-toolbar">
        <div className="search-wrapper compact">
          <span className="search-icon">⌕</span>
          <input
            className="search-input"
            value={searchQuery}
            onChange={(event) => onSearchQueryChange(event.target.value)}
            placeholder="搜索任务"
          />
        </div>

        <div className="toolbar compact-toolbar">
          <button className="btn-text" onClick={onRefresh} disabled={isSyncing}>
            {isSyncing ? "同步中" : "刷新"}
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

      <div className="filter-tabs task-pool-mode-switcher">
        <button className={`filter-tab${viewMode === "list" ? " active" : ""}`} onClick={() => setViewMode("list")}>
          列表
        </button>
        <button className={`filter-tab${viewMode === "quadrant" ? " active" : ""}`} onClick={() => setViewMode("quadrant")}>
          四象限
        </button>
        <button className={`filter-tab${viewMode === "cluster" ? " active" : ""}`} onClick={() => setViewMode("cluster")}>
          聚类
        </button>
      </div>

      {viewMode === "list" ? (
        <ul className="task-list">
          {tasks.length === 0 && <li className="empty-state">没有匹配的任务</li>}
          {tasks.map((task) => (
            <TaskItem
              key={task.id}
              task={task}
              onToggleDone={() => onToggleDone(task.id)}
              onArchive={() => onArchive(task.id)}
              onOpenDetail={() => onOpenDetail(task)}
              onEdit={() => onEdit(task)}
            />
          ))}
        </ul>
      ) : (
        <div className="empty-panel">
          {viewMode === "quadrant"
            ? "四象限视图暂未接通，本轮继续以列表作为唯一真实输入面。"
            : "聚类视图暂未接通，等待分组规则和交互边界明确后再接。"}
        </div>
      )}
    </section>
  );
}
