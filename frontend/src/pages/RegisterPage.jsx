import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { extractMessage, useAuth } from '../context/AuthContext';

const empty = { name: '', email: '', password: '', password_confirmation: '' };

export default function RegisterPage() {
  const { register, user } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState(empty);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  if (user) return <Navigate to="/dashboard" replace />;

  const submit = async (event) => {
    event.preventDefault();
    setError('');
    if (form.password !== form.password_confirmation) {
      setError('Las contraseñas no coinciden.');
      return;
    }
    setBusy(true);
    try {
      await register(form);
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
          <h1>Crear cuenta</h1>
          <p>Registro público · rol estudiante</p>
        </div>

        <form onSubmit={submit} className="form">
          {error && <div className="alert alert-error">{error}</div>}

          <label>
            Nombre
            <input
              required
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </label>

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
              minLength={8}
              autoComplete="new-password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
            />
          </label>

          <label>
            Confirmar contraseña
            <input
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={form.password_confirmation}
              onChange={(e) => setForm({ ...form, password_confirmation: e.target.value })}
            />
          </label>

          <button className="btn btn-primary btn-block" disabled={busy}>
            {busy ? 'Creando cuenta…' : 'Registrarse'}
          </button>
        </form>

        <div className="auth-footer">
          ¿Ya tienes cuenta? <Link to="/login">Ingresa aquí</Link>
        </div>
      </div>
    </div>
  );
}
