import { useEffect, useState } from 'react';
import client, { extractMessage } from '../api/client';

const money = (value) =>
  Number(value).toLocaleString('es-BO', { style: 'currency', currency: 'BOB', maximumFractionDigits: 2 });

const emptyObs = { price: '', quantity_demanded: '', observed_at: new Date().toISOString().slice(0, 10), source: 'historico' };

export default function ProductsPage() {
  const [products, setProducts] = useState([]);
  const [selected, setSelected] = useState(null);
  const [detail, setDetail] = useState(null);
  const [estimate, setEstimate] = useState(null);
  const [obs, setObs] = useState(emptyObs);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const loadProducts = () => {
    client.get('/products')
      .then(({ data }) => {
        setProducts(data);
        if (data.length && !selected) selectProduct(data[0].id);
      })
      .catch((err) => setError(extractMessage(err)))
      .finally(() => setLoading(false));
  };

  const selectProduct = (id) => {
    setSelected(id);
    setError('');
    Promise.all([
      client.get(`/products/${id}`),
      client.get(`/products/${id}/estimate`),
      client.get(`/products/${id}/observations`),
    ])
      .then(([detailRes, estimateRes, obsRes]) => {
        setDetail(detailRes.data);
        setEstimate(estimateRes.data);
        setObs((o) => ({ ...o, ...emptyObs }));
      })
      .catch((err) => setError(extractMessage(err)));
  };

  useEffect(() => { loadProducts(); }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const addObservation = async (event) => {
    event.preventDefault();
    setError('');
    try {
      await client.post(`/products/${selected}/observations`, {
        price: Number(obs.price),
        quantity_demanded: Number(obs.quantity_demanded),
        observed_at: obs.observed_at,
        source: obs.source,
      });
      selectProduct(selected);
    } catch (err) {
      setError(extractMessage(err));
    }
  };

  const removeObservation = async (id) => {
    await client.delete(`/products/${selected}/observations/${id}`);
    selectProduct(selected);
  };

  if (loading) return <div className="center-message">Cargando productos…</div>;

  if (!products.length) {
    return (
      <div className="page">
        <div className="panel empty-state">
          <h2>Sin productos</h2>
          <p>Tu cuenta no tiene productos asociados. Usa el usuario demo para explorar el caso de estudio.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <h1>Productos y observaciones</h1>
          <p>Estima la curva de demanda a partir de precios observados</p>
        </div>
      </header>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="product-layout">
        <div className="panel product-list">
          <h3>Productos</h3>
          {products.map((p) => (
            <button
              key={p.id}
              className={`product-item ${selected === p.id ? 'active' : ''}`}
              onClick={() => selectProduct(p.id)}
            >
              <strong>{p.name}</strong>
              <span>{p.sku || 'Sin SKU'} · {p.unit}</span>
              <span className="muted">CV {money(p.variable_cost_unit)}</span>
            </button>
          ))}
        </div>

        <div className="product-detail">
          {detail && estimate && (
            <>
              <div className="panel">
                <div className="detail-head">
                  <div>
                    <h2>{detail.name}</h2>
                    <p>{detail.business?.name} · Stock: {detail.current_stock} {detail.unit}s</p>
                  </div>
                  <span className={`badge ${detail.active ? 'badge-success' : 'badge-muted'}`}>
                    {detail.active ? 'Activo' : 'Inactivo'}
                  </span>
                </div>
                <div className="estimate-box">
                  <div>
                    <span>Función de demanda estimada</span>
                    <strong className="equation">{estimate.equation}</strong>
                  </div>
                  <div className="estimate-stats">
                    <div><span>Intercepto a</span><strong>{Number(estimate.intercept_a).toFixed(4)}</strong></div>
                    <div><span>Pendiente b</span><strong>{Number(estimate.slope_b).toFixed(4)}</strong></div>
                    <div><span>Observaciones</span><strong>{estimate.observations?.length || 0}</strong></div>
                  </div>
                </div>
              </div>

              <div className="panel">
                <h3>Agregar observación</h3>
                <form className="form-grid compact" onSubmit={addObservation}>
                  <label>Precio<input type="number" step="0.01" min="0.01" required value={obs.price} onChange={(e) => setObs({ ...obs, price: e.target.value })} /></label>
                  <label>Cantidad<input type="number" min="0" required value={obs.quantity_demanded} onChange={(e) => setObs({ ...obs, quantity_demanded: e.target.value })} /></label>
                  <label>Fecha<input type="date" required value={obs.observed_at} onChange={(e) => setObs({ ...obs, observed_at: e.target.value })} /></label>
                  <label>Origen
                    <select value={obs.source} onChange={(e) => setObs({ ...obs, source: e.target.value })}>
                      <option value="historico">Histórico</option>
                      <option value="estimado">Estimado</option>
                    </select>
                  </label>
                  <div className="form-actions"><button className="btn btn-primary">Agregar</button></div>
                </form>
              </div>

              <div className="panel">
                <h3>Observaciones registradas</h3>
                {detail.observations?.length ? (
                  <div className="table-wrap">
                    <table className="data-table">
                      <thead><tr><th>Precio</th><th>Cantidad</th><th>Fecha</th><th>Origen</th><th></th></tr></thead>
                      <tbody>
                        {detail.observations.map((o) => (
                          <tr key={o.id}>
                            <td>{money(o.price)}</td>
                            <td>{o.quantity_demanded}</td>
                            <td>{o.observed_at}</td>
                            <td><span className="badge badge-muted">{o.source}</span></td>
                            <td><button className="btn btn-xs btn-danger-ghost" onClick={() => removeObservation(o.id)}>Eliminar</button></td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <p className="muted">Sin observaciones.</p>
                )}
              </div>

              {detail.costHistory?.length > 0 && (
                <div className="panel">
                  <h3>Historial de costos</h3>
                  <div className="table-wrap">
                    <table className="data-table">
                      <thead><tr><th>Costo anterior</th><th>Costo nuevo</th><th>Fecha</th></tr></thead>
                      <tbody>
                        {detail.costHistory.map((h) => (
                          <tr key={h.id}><td>{money(h.old_cost)}</td><td>{money(h.new_cost)}</td><td>{h.changed_at || h.created_at}</td></tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
