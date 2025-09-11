import { moneyUSD } from "../utils/money.js";

// Table of selected products with remove and PDF export actions
export default function SelectedList({ items, onClear, onDownloadPdf }) {
  return (
    <div className="card">
      <div style={{ padding: 14 }}>
        <div className="header-row">
          <strong>Seleccionados</strong>
          <div style={{ display: "flex", gap: 8 }}>
            <button className="btn secondary" onClick={onClear}>
              Vaciar
            </button>
            <button className="btn" onClick={onDownloadPdf}>
              Descargar PDF
            </button>
          </div>
        </div>
      </div>
      <div className="selected-wrap">
        <table className="table">
          <thead>
            <tr>
              <th style={{ width: 60 }}>Quitar</th>
              <th className="col-code">Código</th>
              <th>Nombre</th>
              <th>Proveedor</th>
              <th>Admin USD</th>
              <th>Tu USD</th>
              <th>Stock</th>
            </tr>
          </thead>
          <tbody>
            {items.length === 0 ? (
              <tr>
                <td
                  colSpan={7}
                  style={{ color: "#6b7280", textAlign: "center" }}
                >
                  No hay productos seleccionados.
                </td>
              </tr>
            ) : (
              items.map((p) => (
                <tr key={p.id}>
                  <td>
                    <button
                      className="btn secondary"
                      onClick={() => p.onRemove?.(p.id)}
                    >
                      Quitar
                    </button>
                  </td>
                  <td className="code">{p.code}</td>
                  <td>{p.name}</td>
                  <td>{p.providerName}</td>
                  <td>{moneyUSD(p.adminUsd)}</td>
                  <td style={{ fontWeight: 700 }}>
                    {moneyUSD(p.ourUsd ?? p.tuUsd ?? p.adminUsd)}
                  </td>
                  <td>{p.stockLabel || "-"}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}