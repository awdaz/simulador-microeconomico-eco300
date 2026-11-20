import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import client, { extractMessage } from '../api/client';
import MetricCard from '../components/MetricCard';
import ProfitChart from '../components/ProfitChart';
import { useAuth } from '../context/AuthContext';

const money = (value) =>
  Number(value).toLocaleString('es-BO', { style: 'currency', currency: 'BOB', maximumFractionDigits: 2 });

const num = (value, digits = 2) => Number(value).toLocaleString('es-BO', {
  minimumFractionDigits: digits,
  maximumFractionDigits: digits,
});

const demandLabel = {
  elastic: 'Elástica',
  inelastic: 'Inelástica',
  unitary: 'Unitaria',
};

export default function DashboardPage() {
  const { user } = useAuth();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    client.get('/dashboard').then(({ data }) => setData(data)).catch((err) => setError(extractMessage(err)));
  }, []);

  if (error) return <div className="alert alert-error">{error}</div>;
  if (!data) return <div className="center-message">Cargando resumen…</div>;

  const sim = data.latest_simulation;
  const curve = sim?.results || [];

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <h1>Hola, {user?.name?.split(' ')[0]} 👋</h1>
          <p>Resumen de tu actividad en el simulador</p>
        </div>
        <Link to="/simulations" className="btn btn-primary">+ Nueva simulación</Link>
      </header>

      <div className="metric-grid">
        <MetricCard label="Simulaciones" value={data.totals.simulations} hint="guardadas" tone="indigo" />
        <MetricCard label="Productos" value={data.totals.products} hint="asociados a tu cuenta" tone="blue" />
        {sim && (
          <>
            <MetricCard label="Precio óptimo" value={money(sim.optimal_price)} hint={`Q* = ${num(sim.optimal_quantity, 4)}`} tone="green" />
            <MetricCard label="Beneficio máximo" value={money(sim.max_profit)} hint={`EPD ${num(sim.epd, 4)} · ${demandLabel[sim.demand_type] || sim.demand_type}`} tone="amber" />
          </>
        )}
      </div>

      {sim ? (
        <>
          <div className="section-head">
            <div>
              <h2>Última simulación: {sim.name}</h2>
              <p>
                Demanda estimada: Q = {num(sim.intercept_a)} − {num(sim.slope_b)}P ·
                CV = {money(sim.variable_cost)} · CF = {money(sim.fixed_cost)}
              </p>
            </div>
            <Link to={`/simulations/${sim.id}`} className="btn btn-secondary">Ver detalle</Link>
          </div>

          <div className="grid-2">
            <ProfitChart curve={curve} optimalPrice={sim.optimal_price} />

            <div className="panel">
              <h3>Indicadores clave</h3>
              <div className="kv-list">
                <div><span>Cantidad óptima</span><strong>{num(sim.optimal_quantity, 4)}</strong></div>
                <div><span>Ingreso en el óptimo</span><strong>{money(curve.find((r) => r.is_optimal)?.revenue || 0)}</strong></div>
                <div><span>Costo en el óptimo</span><strong>{money(curve.find((r) => r.is_optimal)?.total_cost || 0)}</strong></div>
                <div><span>Elasticidad precio</span><strong>{num(sim.epd, 4)}</strong></div>
                <div><span>Tipo de demanda</span><strong>{demandLabel[sim.demand_type] || sim.demand_type}</strong></div>
                <div>
                  <span>Puntos de equilibrio</span>
                  <strong>{sim.break_even_min != null ? `${num(sim.break_even_min)} – ${num(sim.break_even_max)}` : '—'}</strong>
                </div>
              </div>
            </div>
          </div>
        </>
      ) : (
        <div className="panel empty-state">
          <h2>Aún no hay simulaciones</h2>
          <p>Crea tu primera simulación para ver el análisis de demanda y beneficios.</p>
          <Link to="/simulations" className="btn btn-primary">Crear simulación</Link>
        </div>
      )}

      {data.recent_simulations?.length > 1 && (
        <div className="panel">
          <h3>Simulaciones recientes</h3>
          <div className="recent-list">
            {data.recent_simulations.map((item) => (
              <Link key={item.id} to={`/simulations/${item.id}`} className="recent-item">
                <strong>{item.name}</strong>
                <span>{item.product?.name || 'Producto'}</span>
                <span className="recent-price">P* {money(item.optimal_price)}</span>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
