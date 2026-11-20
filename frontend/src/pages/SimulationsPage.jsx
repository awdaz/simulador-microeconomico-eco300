import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import client, { extractMessage } from '../api/client';

const money = (value) =>
  Number(value).toLocaleString('es-BO', { style: 'currency', currency: 'BOB', maximumFractionDigits: 2 });

const fmtDate = (value) =>
  new Date(value).toLocaleString('es-BO', { dateStyle: 'medium', timeStyle: 'short' });

export default function SimulationsPage() {
  const navigate = useNavigate();
  const [simulations, setSimulations] = useState([]);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    product_id: '',
    name: '',
    price_min: 4,
    price_max: 25,
    price_step: 0.5,
    cv_override: '',
    cf_override: '',
  });

  const load = () => {
    Promise.all([client.get('/simulations'), client.get('/products')])
      .then(([sims, prods]) => {
        setSimulations(sims.data.data || sims.data);
        setProducts(prods.data);
        if (prods.data.length && !form.product_id) {
          setForm((f) => ({ ...f, product_id: prods.data[0].id }));
        }
      })
      .catch((err) => setError(extractMessage(err)))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const submit = async (event) => {
    event.preventDefault();
    setError('');
    const payload = {
      product_id: Number(form.product_id),
      name: form.name.trim() || `Simulación ${new Date().toLocaleDateString('es-BO')}`,
      price_min: Number(form.price_min),
      price_max: Number(form.price_max),
      price_step: Number(form.price_step),
    };
    if (form.cv_override !== '') payload.cv_override = Number(form.cv_override);
    if (form.cf_override !== '') payload.cf_override = Number(form.cf_override);

    try {
      const { data } = await client.post('/simulations', payload);
      navigate(`/simulations/${data.id}`);
    } catch (err) {
      setError(extractMessage(err));
    }
  };

  const remove = async (id) => {
    if (!window.confirm('¿Eliminar esta simulación?')) return;
    await client.delete(`/simulations/${id}`);
    load();
  };

  if (loading) return <div className="center-message">Cargando simulaciones…</div>;

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <h1>Simulaciones</h1>
          <p>Ejecuta y administra tus escenarios de precios</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancelar' : '+ Nueva simulación'}
        </button>
      </header>

      {error && <div className="alert alert-error">{error}</div>}

      {showForm && (
        <form className="panel form-grid" onSubmit={submit}>
          <div className="form-section-title">Parámetros de la simulación</div>

          <label>
            Producto
            <select value={form.product_id} onChange={(e) => setForm({ ...form, product_id: e.target.value })} required>
              {products.map((p) => (
                <option key={p.id} value={p.id}>{p.name} {p.sku ? `(${p.sku})` : ''}</option>
              ))}
            </select>
          </label>

          <label>
            Nombre
            <input value={form.name} placeholder="Ej. Escenario navideño" onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </label>

          <label>
            Precio mínimo
            <input type="number" step="0.01" min="0.01" value={form.price_min} onChange={(e) => setForm({ ...form, price_min: e.target.value })} required />
          </label>

          <label>
            Precio máximo
            <input type="number" step="0.01" min="0.01" value={form.price_max} onChange={(e) => setForm({ ...form, price_max: e.target.value })} required />
          </label>

          <label>
            Paso
            <input type="number" step="0.01" min="0.01" value={form.price_step} onChange={(e) => setForm({ ...form, price_step: e.target.value })} required />
          </label>

          <label>
            CV unitario (opcional)
            <input type="number" step="0.01" min="0" placeholder="Usa el del producto" value={form.cv_override} onChange={(e) => setForm({ ...form, cv_override: e.target.value })} />
          </label>

          <label>
            Costo fijo (opcional)
            <input type="number" step="0.01" min="0" placeholder="Usa el de la empresa" value={form.cf_override} onChange={(e) => setForm({ ...form, cf_override: e.target.value })} />
          </label>

          <div className="form-actions">
            <button className="btn btn-primary" type="submit">Ejecutar simulación</button>
          </div>
        </form>
      )}

      <div className="panel">
        {simulations.length === 0 ? (
          <div className="empty-state small">
            <p>No hay simulaciones todavía.</p>
          </div>
        ) : (
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Nombre</th>
                  <th>Producto</th>
                  <th>P*</th>
                  <th>Q*</th>
                  <th>Beneficio</th>
                  <th>EPD</th>
                  <th>Fecha</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {simulations.map((sim) => (
                  <tr key={sim.id}>
                    <td><Link to={`/simulations/${sim.id}`} className="link-strong">{sim.name}</Link></td>
                    <td>{sim.product?.name || '—'}</td>
                    <td>{money(sim.optimal_price)}</td>
                    <td>{Number(sim.optimal_quantity).toFixed(4)}</td>
                    <td className="positive">{money(sim.max_profit)}</td>
                    <td>{Number(sim.epd).toFixed(4)}</td>
                    <td className="muted">{fmtDate(sim.created_at)}</td>
                    <td className="row-actions">
                      <Link to={`/simulations/${sim.id}`} className="btn btn-xs btn-secondary">Ver</Link>
                      <button className="btn btn-xs btn-danger-ghost" onClick={() => remove(sim.id)}>Eliminar</button>
                    </td>
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
