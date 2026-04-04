import { useState, type MouseEvent } from "react";

interface QuickAddDockProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  onOpenDetail: () => void;
  onOpenSequence: () => void;
}

export default function QuickAddDock({ value, onChange, onSubmit, onOpenDetail, onOpenSequence }: QuickAddDockProps) {
  const [focused, setFocused] = useState(false);
  const isExpanded = focused || value.trim().length > 0;
  const canSubmit = value.trim().length > 0;

  const preserveFocusDuringAction = (event: MouseEvent<HTMLButtonElement>) => {
    event.preventDefault();
  };

  const runDockAction = (action: () => void) => {
    setFocused(false);
    action();
  };

  return (
    <div className="quick-add-shell">
      <div className="quick-add-halo" />
      <div className={`quick-add-dock${isExpanded ? " expanded" : ""}`}>
        <span className="quick-add-icon">+</span>
        <input
          className="quick-add-input"
          type="text"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              onSubmit();
            }
          }}
          placeholder="添加任务，例如：周报 90分钟 明天 #工作"
        />

        <div className={`quick-add-actions${isExpanded ? " visible" : ""}`}>
          <button
            className="quick-add-secondary"
            onMouseDown={preserveFocusDuringAction}
            onClick={() => runDockAction(onOpenDetail)}
          >
            详情
          </button>
          <button
            className="quick-add-secondary"
            onMouseDown={preserveFocusDuringAction}
            onClick={() => runDockAction(onOpenSequence)}
          >
            序列
          </button>
          <button
            className="quick-add-primary"
            onMouseDown={preserveFocusDuringAction}
            onClick={() => runDockAction(onSubmit)}
            disabled={!canSubmit}
          >
            ↑
          </button>
        </div>
      </div>
    </div>
  );
}
