import {
  HORIZON_OPTIONS,
  formatScheduleClock,
  formatScheduleDay,
  type DayBlockGroup,
  type ScheduleView
} from "@retodo/core";

interface SchedulePanelProps {
  horizonDays: number;
  onChangeHorizon: (days: number) => void;
  scheduleView: ScheduleView;
  blocksByDay: DayBlockGroup[];
}

export default function SchedulePanel({
  horizonDays,
  onChangeHorizon,
  scheduleView,
  blocksByDay
}: SchedulePanelProps) {
  return (
    <section className="card">
      <div className="panel-header">
        <div className="panel-title">时间视图</div>
        <div className="horizon-tabs">
          {HORIZON_OPTIONS.map((option) => (
            <button
              key={option.days}
              className={`btn-text${horizonDays === option.days ? " active" : ""}`}
              onClick={() => onChangeHorizon(option.days)}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>

      {scheduleView.warnings.length > 0 && (
        <div className="warning-list">
          {scheduleView.warnings.map((warning, index) => (
            <div key={`${warning.code}-${index}`} className={`warning-item ${warning.severity}`}>
              {warning.message}
            </div>
          ))}
        </div>
      )}

      <div className="schedule-grid">
        <div className="schedule-column">
          <div className="subpanel-title">时间块</div>
          {blocksByDay.length === 0 && <div className="empty-panel">暂无时间块</div>}
          {blocksByDay.map((group) => (
            <div key={group.dayKey} className="day-group">
              <div className="day-heading">{formatScheduleDay(group.blocks[0]?.startAt ?? `${group.dayKey}T00:00:00`)}</div>
              <div className="block-list">
                {group.blocks.map((block) => {
                  const step = scheduleView.orderedSteps.find((item) => item.stepId === block.stepId);
                  return (
                    <div key={block.id} className="schedule-block">
                      <div className="schedule-block-time">
                        {formatScheduleClock(block.startAt)} - {formatScheduleClock(block.endAt)}
                      </div>
                      <div className="schedule-block-title">
                        {step?.taskTitle ?? "任务"} / {step?.title ?? "步骤"}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>

        <div className="schedule-column">
          <div className="subpanel-title">任务序列</div>
          <div className="ordered-list">
            {scheduleView.orderedSteps.map((step) => (
              <div key={step.stepId} className={`ordered-item${step.remainingMinutes > 0 ? " unscheduled" : ""}`}>
                <div className="ordered-title">
                  {step.taskTitle}
                  {step.title !== step.taskTitle && <span className="ordered-step-name"> / {step.title}</span>}
                </div>
                <div className="ordered-meta">
                  <span>已排 {step.plannedMinutes}m</span>
                  <span className="task-meta-sep">剩余 {step.remainingMinutes}m</span>
                  {step.dueAt && <span className="task-meta-sep">DDL {step.dueAt.slice(0, 10)}</span>}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
