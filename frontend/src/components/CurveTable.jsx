const num = (value, digits = 2) => Number(value).toLocaleString('es-BO', {
  minimumFractionDigits: digits,
  maximumFractionDigits: digits,
});

export default function CurveTable({ curve, breakEvenMin, breakEvenMax }) {
  const rows = curve || [];

  if (!rows.length) return <p className="muted">Sin datos de grilla.</p>;

  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>Precio</th>
            <th>Cantidad</th>
            <th>Ingreso</th>
            <th>Costo total</th>
            <th>Beneficio</th>
            <th>EPD</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => {
            const inBreakEven =
              breakEvenMin != null &&
              breakEvenMax != null &&
              Number(row.price) >= Number(breakEvenMin) &&
              Number(row.price) <= Number(breakEvenMax);
            return (
              <tr key={row.id} className={row.is_optimal ? 'row-optimal' : ''}>
                <td>{num(row.price)}</td>
                <td>{num(row.quantity, 4)}</td>
                <td>{num(row.revenue)}</td>
                <td>{num(row.total_cost)}</td>
                <td className={Number(row.profit) < 0 ? 'negative' : 'positive'}>{num(row.profit)}</td>
                <td>{num(row.epd, 4)}</td>
                <td>
                  {row.is_optimal && <span className="badge badge-success">Óptimo</span>}
                  {!row.is_optimal && inBreakEven && <span className="badge badge-info">Equilibrio</span>}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
