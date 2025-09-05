# backend\setup-import-xlsx-crestron.ps1
# Importador XLSX adaptado al formato de tu Excel (fila 2 = cabeceras reales).
# Endpoint: POST /pricelists/import-xlsx?supplierName=...&sourceLabel=...&rawCurrency=...

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

Write-Host "==> Instalando dependencias de importación XLSX" -ForegroundColor Cyan
npm install multer xlsx --save | Out-Null
npm install -D @types/multer | Out-Null

# ---- middleware upload ----
$mwDir = Join-Path $here "src\middleware"
New-Item -ItemType Directory -Force -Path $mwDir | Out-Null
@"
import multer from 'multer';
import path from 'path';
import fs from 'fs';

const tmpDir = path.join(process.cwd(), 'tmp');
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir);

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, tmpDir),
  filename: (_req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, unique + '-' + file.originalname.replace(/\s+/g, '_'));
  }
});

export const upload = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB
  fileFilter: (_req, file, cb) => {
    if (!file.originalname.match(/\.(xlsx|xls)$/i)) {
      return cb(new Error('INVALID_FILE_TYPE'));
    }
    cb(null, true);
  }
});
"@ | Out-File -FilePath (Join-Path $mwDir "upload.ts") -Encoding utf8 -Force

# ---- parser específico de tu XLSX ----
$plDir = Join-Path $here "src\modules\pricelists"
New-Item -ItemType Directory -Force -Path $plDir | Out-Null
@"
import * as XLSX from 'xlsx';

// Limpia texto -> número USD: "$ 2,750.00" => 2750.00
function parseUsd(val: any): number | null {
  if (val === null || val === undefined) return null;
  if (typeof val === 'number') return val;
  const s = String(val).replace(/\$/g, '').replace(/\s/g, '').replace(/\./g, '').replace(/,/g, '.');
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
  if (s.includes('menos de')) return 5; // regla práctica para tu archivo
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

export function parseCrestronXlsx(filePath: string): { rows: ParsedXlsxItem[], notes: string[] } {
  const notes: string[] = [];
  const wb = XLSX.readFile(filePath, { cellDates: true });
  const sheetName = wb.SheetNames[0];
  const ws = wb.Sheets[sheetName];

  // Tomamos la fila 2 como cabecera real (fila 1 era el título 'Lista de precios')
  const raw = XLSX.utils.sheet_to_json<any>(ws, { header: 1, defval: null });
  if (!raw.length || raw.length < 3) return { rows: [], notes: ['Archivo vacío o con formato inesperado'] };

  const headerRow = raw[1]; // índice 1 (segunda fila)
  const rows = raw.slice(2); // datos desde la tercera fila

  // Armar índice de columnas por nombre esperado
  // Ejemplo en tu archivo:
  // [ 'Código de artículo', 'Artículo', 'Precio', 'Descuento', 'Precio final', 'Código de impuesto', 'Impuesto', 'Moneda', 'LAREDO', 'MIAMI', 'Info Fábrica' ]
  const idx = (name: string) => headerRow.findIndex((h: any) => String(h ?? '').toLowerCase().trim() === name.toLowerCase());

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
    descripcion: idx('descripcion') >= 0 ? idx('descripcion') : idx('descripción'),
    foto: idx('foto'),
    precio: idx('precio')
  };

  const out: ParsedXlsxItem[] = [];

  for (const r of rows) {
    const code = col.codigo >= 0 ? r[col.codigo] : null;
    if (!code) continue;

    const name = col.articulo >= 0 ? r[col.articulo] : null;

    // Por tu requerimiento, para Crestron el precio base viene en 'Precio final'
    const base = col.precioFinal >= 0 ? parseUsd(r[col.precioFinal]) :
                 col.precio >= 0 ? parseUsd(r[col.precio]) : null;

    if (base == null) {
      // si no hay precio, lo saltamos
      continue;
    }

    const currency = col.moneda >= 0 ? String(r[col.moneda] ?? '').toUpperCase() : 'USD';
    if (currency !== 'USD') {
      notes.push(\`Fila con moneda distinta a USD (\${currency}) para código \${code}\`);
    }

    const stockLaredo = col.laredo >= 0 ? parseStock(r[col.laredo]) : null;
    const stockMiami = col.miami >= 0 ? parseStock(r[col.miami]) : null;

    const manufacturerInfo = col.infoFab >= 0 ? r[col.infoFab] : null;

    out.push({
      code: String(code),
      name: name ? String(name) : String(code),
      brand: col.brand >= 0 ? r[col.brand] : undefined,
      family: col.family >= 0 ? r[col.family] : undefined,
      description: col.descripcion >= 0 ? r[col.descripcion] : undefined,
      photoUrl: col.foto >= 0 ? r[col.foto] : undefined,
      basePriceUsd: base,
      markupPct: 0,
      impuestosPct: 0,
      ivaPct: 0,
      stockMiami,
      stockLaredo,
      manufacturerInfo
    });
  }

  return { rows: out, notes };
}
"@ | Out-File -FilePath (Join-Path $plDir "xlsx.parser.ts") -Encoding utf8 -Force

# ---- controlador y ruta import-xlsx ----
@"
import { Request, Response, NextFunction } from 'express';
import { importPriceList } from './pricelists.service';
import { parseCrestronXlsx } from './xlsx.parser';

export async function importXlsxController(req: Request, res: Response, next: NextFunction) {
  try {
    const supplierName = (req.query.supplierName as string) || undefined;
    const supplierId = (req.query.supplierId as string) || undefined;
    const sourceLabel = (req.query.sourceLabel as string) || undefined;
    const rawCurrency = (req.query.rawCurrency as string) || 'USD';

    // @ts-ignore file agregado por multer
    const file = req.file as Express.Multer.File | undefined;
    if (!file) return res.status(400).json({ error: 'FILE_REQUIRED' });

    const { rows, notes } = parseCrestronXlsx(file.path);
    if (!rows.length) return res.status(400).json({ error: 'NO_ROWS_PARSED' });

    const pl = await importPriceList({
      supplierId,
      supplierName,
      sourceLabel,
      effectiveDate: new Date(),
      rawCurrency,
      items: rows
    });

    res.status(201).json({ priceList: pl, imported: rows.length, notes });
  } catch (err) { next(err); }
}
"@ | Out-File -FilePath (Join-Path $plDir "import-xlsx.controller.ts") -Encoding utf8 -Force

# ---- actualizar pricelists.routes.ts para sumar /import-xlsx ----
@"
import { Router } from 'express';
import { listPriceListsController, importPriceListController } from './pricelists.controller';
import { importXlsxController } from './import-xlsx.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';
import { upload } from '../../middleware/upload';

const router = Router();

// Sólo admin por ahora
router.use(authGuard, adminGuard);

router.get('/', listPriceListsController);
router.post('/import', importPriceListController);

// Nuevo: importación por XLSX (multipart/form-data con key 'file')
router.post('/import-xlsx', upload.single('file'), importXlsxController);

export default router;
"@ | Out-File -FilePath (Join-Path $plDir "pricelists.routes.ts") -Encoding utf8 -Force

Write-Host "✅ Importador XLSX creado. Reiniciá con: npm run dev" -ForegroundColor Green
