import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Scatter,
  ScatterChart,
  Tooltip,
  XAxis,
  YAxis,
  ZAxis,
} from 'recharts';

export default function DemandChart({ curve, observations, optimalQuantity, optimalPrice }) {
  const demand = (curve || []).map((row) => ({
    price: Number(row.price),
    quantity: Number(row.quantity),
  }));
  const obs = (observations || []).map((row) => ({
    price: Number(row.price),
    quantity: Number(row.quantity_demanded),
  }));

  return (
    <div className="chart-box">
      <h3>Curva de demanda</h3>
      <ResponsiveContainer width="100%" height={300}>
          <LineChart data={demand} margin={{ top: 10, right: 20, bottom: 10, left: 10 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey="quantity" label={{ value: 'Cantidad (Q)', position: 'insideBottom', offset: -5 }} />
            <YAxis label={{ value: 'Precio (P)', angle: -90, position: 'insideLeft' }} />
            <Tooltip formatter={(v) => Number(v).toFixed(2)} labelFormatter={(v) => `Q = ${v}`} />
            <Line type="linear" dataKey="price" stroke="#6366f1" dot={false} strokeWidth={2} name="Demanda" />
            {optimalQuantity != null && (
              <ReferenceLine x={Number(optimalQuantity)} stroke="#dc2626" strokeDasharray="5 4" />
            )}
            {optimalPrice != null && (
              <ReferenceLine y={Number(optimalPrice)} stroke="#dc2626" strokeDasharray="5 4" />
            )}
          </LineChart>
      </ResponsiveContainer>

      {obs.length > 0 && (
        <div className="observations-inline">
          <h4>Observaciones registradas</h4>
          <ResponsiveContainer width="100%" height={220}>
            <ScatterChart margin={{ top: 10, right: 20, bottom: 10, left: 10 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
              <XAxis type="number" dataKey="price" name="Precio" />
              <YAxis type="number" dataKey="quantity" name="Cantidad" />
              <ZAxis range={[60, 60]} />
              <Tooltip cursor={{ strokeDasharray: '3 3' }} />
              <Scatter data={obs} fill="#8b5cf6" />
            </ScatterChart>
          </ResponsiveContainer>
        </div>
      )}
    </div>
  );
}
