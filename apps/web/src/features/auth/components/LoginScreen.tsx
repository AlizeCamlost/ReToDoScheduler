import { type FormEvent, useEffect, useMemo, useState } from "react";
import { loadPreferredDeviceName, savePreferredDeviceName, suggestDeviceName } from "../../../shared/storage/deviceSession";

interface LoginScreenProps {
  isSubmitting: boolean;
  errorMessage: string;
  loginEnabled: boolean;
  onSubmit: (payload: { username: string; password: string; deviceName: string }) => Promise<void> | void;
}

export default function LoginScreen({
  isSubmitting,
  errorMessage,
  loginEnabled,
  onSubmit
}: LoginScreenProps) {
  const initialDeviceName = useMemo(() => loadPreferredDeviceName() || suggestDeviceName(), []);
  const [username, setUsername] = useState("owner");
  const [password, setPassword] = useState("");
  const [deviceName, setDeviceName] = useState(initialDeviceName);

  useEffect(() => {
    if (!deviceName.trim()) {
      setDeviceName(suggestDeviceName());
    }
  }, [deviceName]);

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!loginEnabled || isSubmitting) return;

    const normalizedDeviceName = deviceName.trim() || suggestDeviceName();
    savePreferredDeviceName(normalizedDeviceName);
    await onSubmit({
      username: username.trim(),
      password,
      deviceName: normalizedDeviceName
    });
  };

  return (
    <main className="auth-shell">
      <div className="shell-background" />
      <section className="auth-card" aria-label="登录">
        <div className="auth-brand">Norn</div>
        <h1>登录</h1>

        <form className="modal-form" onSubmit={handleSubmit}>
          <div className="modal-body">
            <div className="form-group">
              <label className="form-label" htmlFor="login-username">
                用户名
              </label>
              <input
                id="login-username"
                className="form-input"
                autoComplete="username"
                value={username}
                onChange={(event) => setUsername(event.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="login-password">
                密码
              </label>
              <input
                id="login-password"
                className="form-input"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="login-device-name">
                设备名
              </label>
              <input
                id="login-device-name"
                className="form-input"
                autoComplete="off"
                value={deviceName}
                onChange={(event) => setDeviceName(event.target.value)}
              />
            </div>

            {errorMessage && <div className="auth-error">{errorMessage}</div>}
            {!loginEnabled && <div className="auth-error">服务端未配置 Web 登录。</div>}
          </div>

          <div className="modal-footer">
            <button type="submit" className="btn-primary auth-submit" disabled={isSubmitting || !loginEnabled}>
              {isSubmitting ? "登录中" : "登录"}
            </button>
          </div>
        </form>
      </section>
    </main>
  );
}
