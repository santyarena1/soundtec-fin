// frontend/src/pages/Products.tsx
import { useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { useAuth } from "../lib/auth";

declare global {
  interface Window {
    jspdf?: any; // jsPDF UMD
  }
}

type Product = {
  id: string;
  code: string;
  name: string;
  brand?: string | null;
  family?: string | null;
  stockMiami?: number | null;
  stockLaredo?: number | null;
  supplier?: { id: string; name: string } | null;
  pricing?: {
    priceItemId?: string;
    basePriceUsd: number;
    markupPct: number;
    impuestosPct: number;
    ivaPct: number;
    finalAdminUsd: number;
    priceForUserUsd: number;
    effectiveDate: string;
  } | null;
};

const fmtUSD = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

async function ensureJsPDF() {
  if (window.jspdf?.jsPDF) return window.jspdf.jsPDF;
  await new Promise<void>((resolve, reject) => {
    const id = "jspdf-umd";
    if (document.getElementById(id)) return resolve();
    const s = document.createElement("script");
    s.id = id;
    s.src = "https://cdn.jsdelivr.net/npm/jspdf@2.5.1/dist/jspdf.umd.min.js";
    s.async = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("No se pudo cargar jsPDF"));
    document.head.appendChild(s);
  });
  return window.jspdf!.jsPDF;
}

async function ensureAutoTable() {
  // @ts-ignore
  if (window.jspdf?.jsPDF?.API?.autoTable) return;
  await new Promise<void>((resolve, reject) => {
    const id = "jspdf-autotable";
    if (document.getElementById(id)) return resolve();
    const s = document.createElement("script");
    s.id = id;
    s.src = "https://cdn.jsdelivr.net/npm/jspdf-autotable@3.8.2/dist/jspdf.plugin.autotable.min.js";
    s.async = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("No se pudo cargar jsPDF AutoTable"));
    document.head.appendChild(s);
  });
}

/** Convierte /logo.png a dataURL si existe */
async function loadLogoDataURL(path = "/logo.png"): Promise<string | null> {
  try {
    const img = new Image();
    img.crossOrigin = "anonymous";
    const ok = await new Promise<boolean>((resolve) => {
      img.onload = () => resolve(true);
      img.onerror = () => resolve(false);
      img.src = path + "?_=" + Date.now();
    });
    if (!ok) return null;
    const canvas = document.createElement("canvas");
    const maxW = 180;
    const scale = Math.min(1, maxW / img.width);
    canvas.width = Math.round(img.width * scale);
    canvas.height = Math.round(img.height * scale);
    const ctx = canvas.getContext("2d")!;
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/png");
  } catch {
    return null;
  }
}

export default function Products() {
  const { user } = useAuth();
  const isAdmin = user?.role === "admin";

  // Búsqueda / paginado
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [total, setTotal] = useState(0);

  // Datos
  const [items, setItems] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);

  // Seleccionados (sección aparte fija)
  const [pinnedIds, setPinnedIds] = useState<Set<string>>(() => {
    try {
      return new Set(JSON.parse(localStorage.getItem("pinnedProducts") || "[]"));
    } catch {
      return new Set();
    }
  });
  const [pinnedData, setPinnedData] = useState<Record<string, Product>>(() => {
    try {
      return JSON.parse(localStorage.getItem("pinnedData") || "{}");
    } catch {
      return {};
    }
  });
  useEffect(() => {
    localStorage.setItem("pinnedProducts", JSON.stringify(Array.from(pinnedIds)));
  }, [pinnedIds]);
  useEffect(() => {
    localStorage.setItem("pinnedData", JSON.stringify(pinnedData));
  }, [pinnedData]);

  // Edición admin (usar strings para evitar “0” automático)
  const [editTarget, setEditTarget] = useState<{
    productId: string;
    name: string;
    priceItemId: string;
    markupStr: string;
    impuestosStr: string;
    ivaStr: string;
  } | null>(null);

  const [msg, setMsg] = useState<string | null>(null);
  const [lastEditedId, setLastEditedId] = useState<string | null>(null);

  // Logo PDF
  const [logoDataUrl, setLogoDataUrl] = useState<string | null>(null);
  useEffect(() => {
    loadLogoDataURL("/logo.png").then(setLogoDataUrl);
  }, []);

  async function load() {
    setLoading(true);
    try {
      const res = (await api.listProducts({ q, page, pageSize })) as any;
      setItems(res.items);
      setTotal(res.total);

      // refrescar info de seleccionados presentes en la página
      setPinnedData((old) => {
        const updated = { ...old };
        for (const p of res.items as Product[]) {
          if (pinnedIds.has(p.id)) updated[p.id] = p;
        }
        return updated;
      });
    } catch (e: any) {
      setMsg(e.message || "Error al cargar productos");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, pageSize]);

  function pinProduct(p: Product) {
    setPinnedIds((s) => new Set(s).add(p.id));
    setPinnedData((d) => ({ ...d, [p.id]: p }));
  }
  function unpinProduct(id: string) {
    setPinnedIds((s) => {
      const n = new Set(s);
      n.delete(id);
      return n;
    });
    setPinnedData((d) => {
      const n = { ...d };
      delete n[id];
      return n;
    });
  }
  function clearPinned() {
    setPinnedIds(new Set());
    setPinnedData({});
  }

  // Tabla principal: sólo no-seleccionados
  const list = useMemo(
    () => items.filter((p) => !pinnedIds.has(p.id)).sort((a, b) => (a.code || "").localeCompare(b.code || "")),
    [items, pinnedIds]
  );

  // Seleccionados ordenados
  const pinnedList = useMemo(() => {
    const arr = Array.from(pinnedIds).map((id) => pinnedData[id]).filter(Boolean) as Product[];
    arr.sort((a, b) => (a.code || "").localeCompare(b.code || ""));
    return arr;
  }, [pinnedIds, pinnedData]);

  function openEdit(p: Product) {
    if (!p.pricing?.priceItemId) return;
    setEditTarget({
      productId: p.id,
      name: p.name,
      priceItemId: p.pricing.priceItemId,
      markupStr: String(p.pricing.markupPct ?? 0),
      impuestosStr: String(p.pricing.impuestosPct ?? 0),
      ivaStr: String(p.pricing.ivaPct ?? 0),
    });
    setMsg(null);
  }

  async function saveEdit(e: React.FormEvent) {
    e.preventDefault();
    if (!editTarget) return;
    const m = parseFloat(editTarget.markupStr || "0");
    const imp = parseFloat(editTarget.impuestosStr || "0");
    const iva = parseFloat(editTarget.ivaStr || "0");
    try {
      await api.updatePriceItem(editTarget.priceItemId, {
        markupPct: Number.isFinite(m) ? m : 0,
        impuestosPct: Number.isFinite(imp) ? imp : 0,
        ivaPct: Number.isFinite(iva) ? iva : 0,
      });
      setLastEditedId(editTarget.productId);
      setMsg(`? Guardado exitoso: ${editTarget.name}`);
      setEditTarget(null);
      await load();
    } catch (err: any) {
      setMsg(err.message || "Error al guardar cambios");
    }
  }

  async function downloadPinnedPDF() {
    try {
      if (pinnedList.length === 0) {
        setMsg("No hay productos seleccionados.");
        return;
      }
      const jsPDF = await ensureJsPDF();
      await ensureAutoTable();
      const doc = new jsPDF({ unit: "pt", format: "a4" });

      const pageW = doc.internal.pageSize.getWidth();
      const pageH = doc.internal.pageSize.getHeight();
      const marginX = 40;

      const brandColor = [2, 48, 71]; // azul profundo
      const lightRow = [245, 248, 250];

      // Barra superior (marca)
      doc.setFillColor(brandColor[0], brandColor[1], brandColor[2]);
      doc.rect(0, 0, pageW, 64, "F");
      if (logoDataUrl) {
        try {
          doc.addImage(logoDataUrl, "PNG", marginX, 12, 140, 40);
        } catch {}
      }
      doc.setTextColor(255, 255, 255);
      doc.setFont("helvetica", "bold");
      doc.setFontSize(14);
      doc.text("Productos seleccionados", marginX + (logoDataUrl ? 160 : 0), 28);
      doc.setFont("helvetica", "normal");
      doc.setFontSize(10);
      doc.text(new Date().toLocaleString(), marginX + (logoDataUrl ? 160 : 0), 44);

      // Construcción de tabla
      const body = pinnedList.map((p) => [
        p.code || "-",
        (p.name || "-").slice(0, 80),
        p.supplier?.name || "-",
        p.pricing?.finalAdminUsd != null ? fmtUSD.format(p.pricing.finalAdminUsd) : "-",
        p.pricing?.priceForUserUsd != null ? fmtUSD.format(p.pricing.priceForUserUsd) : "-",
        String(p.stockMiami ?? "-"),
        String(p.stockLaredo ?? "-"),
      ]);

      // @ts-ignore
      doc.autoTable({
        head: [["Código", "Producto", "Proveedor", "Admin USD", "Tu USD", "M", "L"]],
        body,
        startY: 80,
        theme: "grid",
        styles: { fontSize: 9, cellPadding: 6, lineWidth: 0.1, halign: "left", valign: "middle" },
        headStyles: { fillColor: brandColor, textColor: 255, fontStyle: "bold" },
        alternateRowStyles: { fillColor: lightRow },
        columnStyles: {
          // ancho pensado para A4 con márgenes 40pt: suma 515 aprox.
          0: { cellWidth: 65 },  // Código
          1: { cellWidth: 180 }, // Producto
          2: { cellWidth: 70 },  // Proveedor
          3: { cellWidth: 70, halign: "right" }, // Admin USD
          4: { cellWidth: 80, halign: "right" }, // Tu USD
          5: { cellWidth: 25, halign: "center" }, // M
          6: { cellWidth: 25, halign: "center" }, // L
        },
        margin: { left: marginX, right: marginX },
        didDrawPage: (data: any) => {
          // Pie con numeración de página
          doc.setTextColor(120);
          doc.setFontSize(10);
          doc.text(
            `Página ${doc.getNumberOfPages()}`,
            pageW - marginX,
            pageH - 16,
            { align: "right" }
          );
        },
      });

      // Resumen
      const finalY = (doc as any).lastAutoTable?.finalY || 80;
      const subtotal = pinnedList.reduce((acc, p) => acc + (p.pricing?.priceForUserUsd ?? 0), 0);
      doc.setTextColor(20);
      doc.setFont("helvetica", "bold");
      doc.setFontSize(11);
      doc.text(`Total de productos: ${pinnedList.length}`, marginX, finalY + 24);
      doc.text(`Subtotal (Tu USD): ${fmtUSD.format(subtotal)}`, marginX, finalY + 42);

      const ts = new Date();
      const name = `productos-seleccionados-${ts.getFullYear()}${String(ts.getMonth() + 1).padStart(2, "0")}${String(ts.getDate()).padStart(2, "0")}-${String(ts.getHours()).padStart(2, "0")}${String(ts.getMinutes()).padStart(2, "0")}.pdf`;
      doc.save(name);
      setMsg(`?? PDF descargado (${pinnedList.length} productos).`);
    } catch (e: any) {
      setMsg(e.message || "No se pudo generar el PDF");
    }
  }

  return (
    <div className="space-y-5">
      {/* Barra superior */}
      <div className="flex flex-col sm:flex-row gap-3 items-end">
        <div className="flex-1">
          <label className="label">Búsqueda</label>
          <input
            className="input mt-1"
            placeholder="Código, nombre, marca..."
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        <button
          className="btn btn-primary"
          onClick={() => {
            setPage(1);
            load();
          }}
        >
          Buscar
        </button>
        <div className="ml-auto text-sm text-gray-600">
          Total: {total} &nbsp;·&nbsp; Seleccionados: {pinnedIds.size}
        </div>
      </div>

      {/* Mensajes */}
      {msg && (
        <div className="card text-sm">
          <div className="font-semibold mb-1">Mensaje</div>
          <div>{msg}</div>
        </div>
      )}

      {/* Seleccionados (fijo arriba) */}
      <div className="card">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">Seleccionados</h2>
          <div className="flex gap-2">
            <button className="btn btn-ghost" onClick={clearPinned} disabled={pinnedList.length===0}>
              Vaciar
            </button>
            <button className="btn btn-primary" onClick={downloadPinnedPDF} disabled={pinnedList.length===0}>
              Descargar PDF
            </button>
          </div>
        </div>

        {pinnedList.length === 0 ? (
          <div className="text-sm text-gray-500 mt-2">No hay productos seleccionados.</div>
        ) : (
          <div className="overflow-auto mt-3">
            <table className="min-w-full">
              <thead>
                <tr>
                  <th className="table-th">Quitar</th>
                  <th className="table-th">Código</th>
                  <th className="table-th">Nombre</th>
                  <th className="table-th">Proveedor</th>
                  <th className="table-th text-right">Admin USD</th>
                  <th className="table-th text-right">Tu USD</th>
                  <th className="table-th text-center">Stock</th>
                </tr>
              </thead>
              <tbody>
                {pinnedList.map((p) => (
                  <tr key={p.id} className="border-b bg-yellow-50/40">
                    <td className="table-td">
                      <button className="btn btn-ghost" onClick={() => unpinProduct(p.id)} title="Quitar de seleccionados">
                        ?
                      </button>
                    </td>
                    <td className="table-td font-mono">{p.code}</td>
                    <td className="table-td">{p.name}</td>
                    <td className="table-td">{p.supplier?.name || "-"}</td>
                    <td className="table-td text-right">
                      {p.pricing?.finalAdminUsd != null ? fmtUSD.format(p.pricing.finalAdminUsd) : "-"}
                    </td>
                    <td className="table-td text-right font-semibold">
                      {p.pricing?.priceForUserUsd != null ? fmtUSD.format(p.pricing.priceForUserUsd) : "-"}
                    </td>
                    <td className="table-td text-center">
                      {p.stockMiami ?? "-"} M / {p.stockLaredo ?? "-"} L
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Panel de edición (admin) */}
      {isAdmin && editTarget && (
        <div className="card">
          <form onSubmit={saveEdit} className="grid grid-cols-1 md:grid-cols-5 gap-3 items-end">
            <div className="md:col-span-5">
              <div className="badge">Editando: {editTarget.name}</div>
            </div>
            <div>
              <label className="label">MarkUp %</label>
              <input
                className="input mt-1"
                type="text"
                inputMode="decimal"
                value={editTarget.markupStr}
                onChange={(e) => setEditTarget((s) => (s ? { ...s, markupStr: e.target.value } : s))}
                placeholder="0"
              />
            </div>
            <div>
              <label className="label">Impuestos %</label>
              <input
                className="input mt-1"
                type="text"
                inputMode="decimal"
                value={editTarget.impuestosStr}
                onChange={(e) =>
                  setEditTarget((s) => (s ? { ...s, impuestosStr: e.target.value } : s))
                }
                placeholder="0"
              />
            </div>
            <div>
              <label className="label">IVA %</label>
              <input
                className="input mt-1"
                type="text"
                inputMode="decimal"
                value={editTarget.ivaStr}
                onChange={(e) => setEditTarget((s) => (s ? { ...s, ivaStr: e.target.value } : s))}
                placeholder="0"
              />
            </div>
            <div className="flex gap-2">
              <button className="btn btn-primary">Guardar</button>
              <button type="button" className="btn btn-ghost" onClick={() => setEditTarget(null)}>
                Cancelar
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Tabla principal (no incluye seleccionados) */}
      <div className="card overflow-auto">
        <table className="min-w-full">
          <thead>
            <tr>
              <th className="table-th">Fijar</th>
              <th className="table-th">Código</th>
              <th className="table-th">Nombre</th>
              <th className="table-th">Marca</th>
              <th className="table-th">Familia</th>
              <th className="table-th">Proveedor</th>
              <th className="table-th text-right">Admin USD</th>
              <th className="table-th text-right">Tu Precio USD</th>
              <th className="table-th text-center">Stock</th>
              <th className="table-th text-center">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {list.map((p) => {
              const isEdited = lastEditedId === p.id;
              return (
                <tr key={p.id} className={`border-b ${isEdited ? "bg-green-50" : ""}`}>
                  <td className="table-td">
                    <button className="btn btn-ghost" title="Fijar arriba" onClick={() => pinProduct(p)}>
                      ?
                    </button>
                  </td>
                  <td className="table-td font-mono">{p.code}</td>
                  <td className="table-td">{p.name}</td>
                  <td className="table-td">{p.brand || "-"}</td>
                  <td className="table-td">{p.family || "-"}</td>
                  <td className="table-td">{p.supplier?.name || "-"}</td>
                  <td className="table-td text-right">
                    {p.pricing?.finalAdminUsd != null ? fmtUSD.format(p.pricing.finalAdminUsd) : "-"}
                  </td>
                  <td className="table-td text-right font-semibold">
                    {p.pricing?.priceForUserUsd != null ? fmtUSD.format(p.pricing.priceForUserUsd) : "-"}
                  </td>
                  <td className="table-td text-center">
                    {p.stockMiami ?? "-"} M / {p.stockLaredo ?? "-"} L
                  </td>
                  <td className="table-td text-center">
                    {isAdmin && p.pricing?.priceItemId ? (
                      <button className="btn btn-ghost" onClick={() => openEdit(p)}>
                        Editar
                      </button>
                    ) : (
                      <span className="text-gray-400">-</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {loading && <div className="text-sm text-gray-500 mt-2">Cargando...</div>}
      </div>

      {/* Paginación */}
      <div className="flex items-center gap-3">
        <button className="btn btn-ghost" onClick={() => setPage((p) => Math.max(1, p - 1))}>
          Anterior
        </button>
        <div>Página {page}</div>
        <button
          className="btn btn-ghost"
          onClick={() => setPage((p) => (p * pageSize < total ? p + 1 : p))}
        >
          Siguiente
        </button>
        <select
          className="input w-28"
          value={pageSize}
          onChange={(e) => {
            setPageSize(parseInt(e.target.value));
            setPage(1);
          }}
        >
          <option value={25}>25</option>
          <option value={50}>50</option>
          <option value={100}>100</option>
        </select>
      </div>
    </div>
  );
}
