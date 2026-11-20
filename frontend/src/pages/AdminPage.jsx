import { useEffect, useState } from 'react';
import client, { extractMessage } from '../api/client';

export default function AdminPage() {
  const [audit, setAudit] = useState([]);
  const [simulations, setSimulations] = useState([]);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('audit');

  useEffect(() => {
    Promise.all([client.get('/admin/audit-log'), client.get('/admin/simulations')])
      .then(([a, s]) => { setAudit(a.data); setSimulations(s.data); })
      .catch((err) => setError(extractMessage(err)));
  }, []);

  const fmtDate = (value) =>
    value ? new Date(value).toLocaleString('es-BO', { dateStyle: 'medium', timeStyle: 'short' }) : '—';

  if (error) return <div className="alert alert-error">{error}</div>;

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <h1>Administración</h1>
          <p>Auditoría y simulaciones de todos los usuarios</p>
        </div>
      </header>

      <div className="tabs">
        <button className={tab === 'audit' ? 'active' : ''} onClick={() => setTab('audit')}>Auditoría ({audit.length})</button>
        <button className={tab === 'sims' ? 'active' : ''} onClick={() => setTab('sims')}>Simulaciones ({simulations.length})</button>
      </div>

      <div className="panel">
        {tab === 'audit' ? (
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>ID</th><th>Tabla</th><th>Operación</th><th>Registro</th><th>Usuario</th><th>Fecha</th></tr></thead>
              <tbody>
                {audit.map((row) => (
                  <tr key={row.id}>
                    <td>{row.id}</td>
                    <td>{row.table_name}</td>
                    <td><span className={`badge badge-${row.operation === 'DELETE' ? 'danger' : row.operation === 'INSERT' ? 'success' : 'info'}`}>{row.operation}</span></td>
                    <td>{row.record_id ?? '—'}</td>
                    <td>{row.user_id ?? 'sistema'}</td>
                    <td className="muted">{fmtDate(row.created_at || row.changed_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>ID</th><th>Nombre</th><th>Usuario</th><th>Producto</th><th>P*</th><th>Beneficio</th><th>Fecha</th></tr></thead>
              <tbody>
                {simulations.map((sim) => (
                  <tr key={sim.id}>
                    <td>{sim.id}</td>
                    <td>{sim.name}</td>
                    <td>{sim.user_id}</td>
                    <td>{sim.product?.name || '—'}</td>
                    <td>{Number(sim.optimal_price).toFixed(2)}</td>
                    <td>{Number(sim.max_profit).toFixed(2)}</td>
                    <td className="muted">{fmtDate(sim.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
