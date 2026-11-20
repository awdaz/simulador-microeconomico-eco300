import {
  Area,
  CartesianGrid,
  ComposedChart,
  Line,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

const money = (value) =>
  Number(value).toLocaleString('es-BO', { style: 'currency', currency: 'BOB', maximumFractionDigits: 0 });

export default function ProfitChart({ curve, optimalPrice }) {
  const data = (curve || []).map((row) => ({ ...row, price: Number(row.price) }));

  return (
    <div className="chart-box">
      <h3>Beneficio por precio</h3>
      <ResponsiveContainer width="100%" height={320}>
        <ComposedChart data={data} margin={{ top: 10, right: 20, bottom: 10, left: 10 }}>
          <defs>
            <linearGradient id="profitFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#10b981" stopOpacity={0.45} />
              <stop offset="95%" stopColor="#10b981" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
          <XAxis dataKey="price" label={{ value: 'Precio (P)', position: 'insideBottom', offset: -5 }} />
          <YAxis tickFormatter={money} width={70} />
          <Tooltip
            formatter={(value, name) => [money(value), { profit: 'Beneficio', revenue: 'Ingreso', total_cost: 'Costo total' }[name] || name]}
            labelFormatter={(label) => `Precio: ${label}`}
          />
          <Area type="monotone" dataKey="profit" stroke="#059669" fill="url(#profitFill)" strokeWidth={2} />
          <Line type="monotone" dataKey="revenue" stroke="#3b82f6" dot={false} strokeWidth={1.5} />
          <Line type="monotone" dataKey="total_cost" stroke="#f59e0b" dot={false} strokeWidth={1.5} />
          {optimalPrice != null && (
            <ReferenceLine x={Number(optimalPrice)} stroke="#dc2626" strokeDasharray="5 4" label={{ value: 'P*', fill: '#dc2626', position: 'top' }} />
          )}
        </ComposedChart>
      </ResponsiveContainer>
      <div className="chart-legend">
        <span><i className="legend-dot green" /> Beneficio</span>
        <span><i className="legend-dot blue" /> Ingreso</span>
        <span><i className="legend-dot amber" /> Costo total</span>
      </div>
    </div>
  );
}
