import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import client, { extractMessage } from '../api/client';
import CurveTable from '../components/CurveTable';
import DemandChart from '../components/DemandChart';
import MetricCard from '../components/MetricCard';
import ProfitChart from '../components/ProfitChart';

const money = (value) =>
  Number(value).toLocaleString('es-BO', { style: 'currency', currency: 'BOB', maximumFractionDigits: 2 });

const num = (value, digits = 2) => Number(value).toLocaleString('es-BO', {
  minimumFractionDigits: digits,
  maximumFractionDigits: digits,
});

export default function SimulationPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [sim, setSim] = useState(null);
  const [curve, setCurve] = useState([]);
  const [observations, setObservations] = useState([]);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('chart');

  const load = () => {
    client.get(`/simulations/${id}`)
      .then(({ data }) => {
        setSim(data);
        setCurve(data.results || []);
        return client.get(`/products/${data.product_id}/observations`);
      })
      .then(({ data }) => setObservations(data))
      .catch((err) => setError(extractMessage(err)));
  };

  useEffect(() => { load(); }, [id]); // eslint-disable-line react-hooks/exhaustive-deps

  const refresh = async () => {
    try {
      const { data } = await client.post(`/simulations/${id}/refresh`);
      setSim(data);
      setCurve(data.results || []);
    } catch (err) {
      setError(extractMessage(err));
    }
  };

  const remove = async () => {
    if (!window.confirm('¿Eliminar esta simulación?')) return;
    await client.delete(`/simulations/${id}`);
    navigate('/simulations');
  };

  if (error) return <div className="alert alert-error">{error}</div>;
  if (!sim) return <div className="center-message">Cargando simulación…</div>;

  const optimal = curve.find((row) => row.is_optimal);

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <div className="breadcrumb"><Link to="/simulations">Simulaciones</Link> / {sim.name}</div>
          <h1>{sim.name}</h1>
          <p>{sim.product?.name || 'Producto'} · {sim.product?.business?.name || ''}</p>
        </div>
        <div className="header-actions">
          <button className="btn btn-secondary" onClick={refresh}>↻ Recalcular</button>
          <button className="btn btn-danger-ghost" onClick={remove}>Eliminar</button>
        </div>
      </header>

      <div className="metric-grid">
        <MetricCard label="Precio óptimo (P*)" value={money(sim.optimal_price)} hint={`Q* = ${num(sim.optimal_quantity, 4)}`} tone="green" />
        <MetricCard label="Beneficio máximo (Π*)" value={money(sim.max_profit)} tone="indigo" />
        <MetricCard label="Elasticidad (EPD)" value={num(sim.epd, 4)} hint={sim.demand_type === 'elastic' ? 'Demanda elástica' : sim.demand_type === 'inelastic' ? 'Demanda inelástica' : 'Demanda unitaria'} tone="amber" />
        <MetricCard label="Umbrales de equilibrio" value={sim.break_even_min != null ? `${num(sim.break_even_min)} – ${num(sim.break_even_max)}` : '—'} hint="precios sin pérdida" tone="blue" />
      </div>

      <div className="panel info-strip">
        <div><span>Demanda estimada</span><strong>Q = {num(sim.intercept_a)} − {num(sim.slope_b)}P</strong></div>
        <div><span>Costo variable unitario</span><strong>{money(sim.variable_cost)}</strong></div>
        <div><span>Costo fijo</span><strong>{money(sim.fixed_cost)}</strong></div>
        <div><span>Rango de precios</span><strong>{num(sim.price_min)} – {num(sim.price_max)} (paso {num(sim.price_step)})</strong></div>
        <div><span>Óptimo en grilla</span><strong>{num(optimal?.price ?? sim.optimal_price)}</strong></div>
      </div>

      <div className="tabs">
        <button className={tab === 'chart' ? 'active' : ''} onClick={() => setTab('chart')}>Gráficos</button>
        <button className={tab === 'table' ? 'active' : ''} onClick={() => setTab('table')}>Grilla de precios ({curve.length})</button>
      </div>

      {tab === 'chart' ? (
        <div className="grid-2">
          <ProfitChart curve={curve} optimalPrice={sim.optimal_price} />
          <DemandChart
            curve={curve}
            observations={observations}
            optimalPrice={sim.optimal_price}
            optimalQuantity={sim.optimal_quantity}
          />
        </div>
      ) : (
        <div className="panel">
          <CurveTable
            curve={curve}
            breakEvenMin={sim.break_even_min}
            breakEvenMax={sim.break_even_max}
          />
        </div>
      )}
    </div>
  );
}
