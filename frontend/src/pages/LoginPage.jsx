import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { extractMessage, useAuth } from '../context/AuthContext';

export default function LoginPage() {
  const { login, user } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: 'admin@economia.test', password: 'password123' });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  if (user) return <Navigate to="/dashboard" replace />;

  const submit = async (event) => {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      await login(form.email, form.password);
      navigate('/dashboard', { replace: true });
    } catch (err) {
      setError(extractMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-header">
          <span className="brand-mark large">ECO</span>
          <h1>Simulador Microeconómico</h1>
          <p>Demanda, costos y beneficios · ECO300</p>
        </div>

        <form onSubmit={submit} className="form">
          {error && <div className="alert alert-error">{error}</div>}

          <label>
            Correo electrónico
            <input
              type="email"
              required
              autoComplete="email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
          </label>

          <label>
            Contraseña
            <input
              type="password"
              required
              autoComplete="current-password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
            />
          </label>

          <button className="btn btn-primary btn-block" disabled={busy}>
            {busy ? 'Ingresando…' : 'Ingresar'}
          </button>
        </form>

        <div className="auth-footer">
          ¿No tienes cuenta? <Link to="/register">Regístrate</Link>
        </div>

        <div className="demo-credentials">
          <strong>Credenciales demo</strong>
          <code>admin@economia.test</code> / <code>password123</code>
        </div>
      </div>
    </div>
  );
}
