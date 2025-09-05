import * as XLSX from 'xlsx';

// Limpia texto -> número USD: "$ 2,750.00" => 2750.00
function parseUsd(val: any): number | null {
  if (val === null || val === undefined) return null;
  if (typeof val === 'number') return val;
  const s = String(val)
    .replace(/\$/g, '')
    .replace(/\s/g, '')
    .replace(/\./g, '')
    .replace(/,/g, '.');
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}

// Extrae cantidad de textos como 'Menos de 5pz', 'No disponible', '10', etc.
function parseStock(txt: any): number | null {
  if (txt == null) return null;
  const s = String(txt).toLowerCase().trim();
  if (!s || s === 'no disponible' || s === 'n/a') return null;
  const m = s.match(/(\d+)/);
  if (m) return parseInt(m[1], 10);
  if (s.includes('menos de')) return 5; // regla práctica
  return null;
}

export type ParsedXlsxItem = {
  code: string;
  name?: string | null;
  brand?: string | null;
  family?: string | null;
  description?: string | null;
  photoUrl?: string | null;
  basePriceUsd: number;
  markupPct?: number;
  impuestosPct?: number;
  ivaPct?: number;
  stockMiami?: number | null;
  stockLaredo?: number | null;
  manufacturerInfo?: any;
};

export function parseCrestronXlsx(
  filePath: string
): { rows: ParsedXlsxItem[]; notes: string[] } {
  const notes: string[] = [];
  const wb = XLSX.readFile(filePath, { cellDates: true });
  const sheetName = wb.SheetNames[0];
  const ws = wb.Sheets[sheetName];

  // Tomamos la fila 2 como cabecera real (fila 1 es un título)
  const raw: any[][] = XLSX.utils.sheet_to_json(ws, { header: 1, defval: null });
  if (!raw.length || raw.length < 3) {
    return { rows: [], notes: ['Archivo vacío o con formato inesperado'] };
  }

  const headerRow = raw[1] as any[]; // segunda fila
  const dataRows = raw.slice(2);     // datos desde la tercera fila

  const idx = (name: string) =>
    headerRow.findIndex(
      (h: any) => String(h ?? '').toLowerCase().trim() === name.toLowerCase()
    );

  const col = {
    codigo: idx('código de artículo'),
    articulo: idx('artículo'),
    precioFinal: idx('precio final'),
    moneda: idx('moneda'),
    laredo: idx('laredo'),
    miami: idx('miami'),
    infoFab: idx('info fábrica'),
    brand: idx('marca'),
    family: idx('familia'),
    descripcion: (() => {
      const a = idx('descripcion');
      return a >= 0 ? a : idx('descripción');
    })(),
    foto: idx('foto'),
    precio: idx('precio')
  };

  const rows: ParsedXlsxItem[] = [];

  for (const r of dataRows) {
    const codeVal = col.codigo >= 0 ? r[col.codigo] : null;
    if (!codeVal) continue;
    const code = String(codeVal);

    const name = col.articulo >= 0 ? r[col.articulo] : null;

    // Para Crestron el precio base viene en 'Precio final' (si no, intenta 'Precio')
    const base =
      col.precioFinal >= 0
        ? parseUsd(r[col.precioFinal])
        : col.precio >= 0
        ? parseUsd(r[col.precio])
        : null;

    if (base == null) continue;

    const currency =
      col.moneda >= 0 ? String(r[col.moneda] ?? '').toUpperCase() : 'USD';
    if (currency && currency !== 'USD') {
      notes.push(
        'Fila con moneda distinta a USD (' + currency + ') para código ' + code
      );
    }

    const stockLaredo = col.laredo >= 0 ? parseStock(r[col.laredo]) : null;
    const stockMiami = col.miami >= 0 ? parseStock(r[col.miami]) : null;

    const manufacturerInfo = col.infoFab >= 0 ? r[col.infoFab] : null;

    rows.push({
      code,
      name: name ? String(name) : code,
      brand:
        col.brand >= 0
          ? r[col.brand] != null
            ? String(r[col.brand])
            : undefined
          : undefined,
      family:
        col.family >= 0
          ? r[col.family] != null
            ? String(r[col.family])
            : undefined
          : undefined,
      description:
        col.descripcion >= 0
          ? r[col.descripcion] != null
            ? String(r[col.descripcion])
            : undefined
          : undefined,
      photoUrl:
        col.foto >= 0
          ? r[col.foto] != null
            ? String(r[col.foto])
            : undefined
          : undefined,
      basePriceUsd: base,
      markupPct: 0,
      impuestosPct: 0,
      ivaPct: 0,
      stockMiami,
      stockLaredo,
      manufacturerInfo
    });
  }

  return { rows, notes };
}
