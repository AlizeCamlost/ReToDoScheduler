import { WEEKDAY_OPTIONS, type TimeTemplate, type WeeklyTimeRange } from "@retodo/core";

interface TimeTemplateEditorProps {
  timeTemplate: TimeTemplate;
  onAddRange: () => void;
  onUpdateRange: (rangeId: string, patch: Partial<WeeklyTimeRange>) => void;
  onRemoveRange: (rangeId: string) => void;
}

export default function TimeTemplateEditor({
  timeTemplate,
  onAddRange,
  onUpdateRange,
  onRemoveRange
}: TimeTemplateEditorProps) {
  return (
    <div className="template-editor">
      <div className="template-header">
        <div className="panel-title">时间模板</div>
        <button className="btn-text" onClick={onAddRange}>
          添加时间段
        </button>
      </div>
      <div className="template-list">
        {timeTemplate.weeklyRanges.map((range) => (
          <div key={range.id} className="template-row">
            <select
              className="form-select"
              value={range.weekday}
              onChange={(event) =>
                onUpdateRange(range.id, { weekday: Number(event.target.value) as WeeklyTimeRange["weekday"] })
              }
            >
              {WEEKDAY_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <input
              className="form-input"
              type="time"
              value={range.startTime}
              onChange={(event) => onUpdateRange(range.id, { startTime: event.target.value })}
            />
            <input
              className="form-input"
              type="time"
              value={range.endTime}
              onChange={(event) => onUpdateRange(range.id, { endTime: event.target.value })}
            />
            <button className="btn-action danger" onClick={() => onRemoveRange(range.id)}>
              删除
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
