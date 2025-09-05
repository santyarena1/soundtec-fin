# patch-admin-and-front.ps1
# Corrige el problema de interpolación en PowerShell y aplica:
# - Backend: instala bcrypt
# - Frontend: API /admin y página de Usuarios con edición + reset de contraseña

$ErrorActionPreference = 'Stop'
$root = Get-Location
$backend = Join-Path $root 'backend'
$frontend = Join-Path $root 'frontend'

function WriteNoBom($path, $text) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $enc = New-Object System.Text.UTF8Encoding($false) # sin BOM
  [System.IO.File]::WriteAllText($path, $text, $enc)
}

# --- Backend: instalar bcrypt ---
if (-not (Test-Path $backend)) { Write-Host 'No encontré backend/'; exit 1 }
Push-Location $backend
npm i bcrypt | Out-Null
try { npm i -D @types/bcrypt | Out-Null } catch {}
Pop-Location

# --- Frontend debe existir ---
if (-not (Test-Path $frontend)) { Write-Host 'No encontré frontend/. Crealo con el script de setup.'; exit 1 }

# --- src/lib/api.ts con rutas /admin ---
$apiTs = @'
const API_BASE = (import.meta as any).env?.VITE_API_BASE || "http://localhost:3000";

function getToken() {
  try { return localStorage.getItem("token"); } catch { return null; }
}

async function request(path: string, opts: RequestInit = {}, auth = true) {
  const token = getToken();
  const headers: any = {};
  if (!(opts.body instanceof FormData)) headers["Content-Type"] = "application/json";
  if (auth && token) headers["Authorization"] = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, { ...opts, headers: { ...headers, ...(opts.headers || {}) } });
  if (!res.ok) {
    let msg = "";
    try { msg = await res.text(); } catch {}
    throw new Error(msg || `HTTP ${res.status}`);
  }
  const ct = res.headers.get("content-type") || "";
  if (ct.includes("application/json")) return res.json();
  return res.text();
}

export const api = {
  // ---- Auth
  async login(email: string, password: string): Promise<{ token: string; user: any }> {
    return request("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) }, false);
  },
  async me(): Promise<{ user: any }> { return request("/auth/me"); },

  // ---- Products
  async listProducts(params: { q?: string; page?: number; pageSize?: number } = {}) {
    const sp = new URLSearchParams();
    if (params.q) sp.append("q", params.q);
    if (params.page) sp.append("page", String(params.page));
    if (params.pageSize) sp.append("pageSize", String(params.pageSize));
    return request(`/products${sp.toString() ? `?${sp}` : ""}`);
  },

  // ---- PriceItems (admin)
  async updatePriceItem(id: string, data: { basePriceUsd?: number; markupPct?: number; impuestosPct?: number; ivaPct?: number; }) {
    return request(`/priceitems/${id}`, { method: "PATCH", body: JSON.stringify(data) });
  },

  // ---- Suppliers (admin)
  async listSuppliers() { return request("/suppliers"); },
  async createSupplier(data: { name: string; slug?: string; websiteUrl?: string; isCrestron?: boolean }) {
    return request("/suppliers", { method: "POST", body: JSON.stringify(data) });
  },

  // ---- Import XLSX (admin)
  async importXlsx(file: File, supplierName: string, sourceLabel: string) {
    const form = new FormData();
    form.append("file", file);
    const sp = new URLSearchParams({ supplierName, sourceLabel, rawCurrency: "USD" });
    const token = getToken();
    const res = await fetch(`${API_BASE}/pricelists/import-xlsx?${sp.toString()}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token || ""}` },
      body: form
    });
    if (!res.ok) throw new Error(await res.text());
    return res.json();
  },

  // ---- Admin users
  async adminListUsers() {
    return request("/admin/users");
  },
  async adminUpdateUser(id: string, data: { email?: string; role?: "admin"|"user"; descuentoPct?: number; isActive?: boolean; }) {
    return request(`/admin/users/${id}`, { method: "PATCH", body: JSON.stringify(data) });
  },
  async adminResetPassword(id: string, newPassword: string) {
    return request(`/admin/users/${id}/reset-password`, { method: "POST", body: JSON.stringify({ newPassword }) });
  },

  // ---- Crear usuario (ruta pública previa)
  async createUser(data: { email: string; password: string; descuentoPct?: number; role?: "admin"|"user" }) {
    return request("/users", { method: "POST", body: JSON.stringify(data) });
  }
};
'@
WriteNoBom (Join-Path $frontend 'src\lib\api.ts') $apiTs

# --- src/pages/Users.tsx con edición + reset password ---
$usersTsx = @'
import { useEffect, useState } from "react";
import { api } from "../lib/api";

type Row = {
  id: string;
  email: string;
  role: "admin" | "user";
  descuentoPct: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  _edit?: { email?: string; role?: "admin"|"user"; descuentoPct?: number; isActive?: boolean; newPassword?: string; };
};

export default function Users() {
  const [items, setItems] = useState<Row[]>([]);
  const [creating, setCreating] = useState(false);
  const [cEmail, setCEmail] = useState("");
  const [cPass, setCPass] = useState("");
  const [cRole, setCRole] = useState<"admin"|"user">("user");
  const [cDesc, setCDesc] = useState(0);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    const data = await api.adminListUsers() as any;
    setItems(data.items);
  }
  useEffect(()=>{ load(); }, []);

  async function createUser() {
    setMsg(null);
    setCreating(true);
    try {
      await api.createUser({ email: cEmail, password: cPass, descuentoPct: cDesc, role: cRole });
      setCEmail(""); setCPass(""); setCDesc(0); setCRole("user");
      await load();
      setMsg("Usuario creado.");
    } catch (e:any) {
      setMsg(e.message);
    } finally {
      setCreating(false);
    }
  }

  function setEdit(id: string, patch: Partial<Row["_edit"]>) {
    setItems(rows => rows.map(r => r.id === id ? ({ ...r, _edit: { ...(r._edit||{}), ...patch } }) : r));
  }

  async function saveRow(r: Row) {
    const changes: any = {};
    if (r._edit?.email !== undefined && r._edit.email !== r.email) changes.email = r._edit.email;
    if (r._edit?.role !== undefined && r._edit.role !== r.role) changes.role = r._edit.role;
    if (r._edit?.descuentoPct !== undefined && r._edit.descuentoPct !== r.descuentoPct) changes.descuentoPct = r._edit.descuentoPct;
    if (r._edit?.isActive !== undefined && r._edit.isActive !== r.isActive) changes.isActive = r._edit.isActive;

    if (Object.keys(changes).length > 0) {
      await api.adminUpdateUser(r.id, changes);
    }
    if (r._edit?.newPassword) {
      await api.adminResetPassword(r.id, r._edit.newPassword);
    }
    await load();
  }

  return (
    <div className="space-y-6">
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Crear usuario</h2>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          <div><label className="label">Email</label><input className="input mt-1" value={cEmail} onChange={e=>setCEmail(e.target.value)} /></div>
          <div><label className="label">Password</label><input className="input mt-1" type="password" value={cPass} onChange={e=>setCPass(e.target.value)} /></div>
          <div><label className="label">Descuento %</label><input className="input mt-1" type="number" value={cDesc} onChange={e=>setCDesc(parseFloat(e.target.value||"0"))} /></div>
          <div>
            <label className="label">Rol</label>
            <select className="input mt-1" value={cRole} onChange={e=>setCRole(e.target.value as any)}>
              <option value="user">user</option>
              <option value="admin">admin</option>
            </select>
          </div>
          <div className="flex items-end"><button className="btn btn-primary w-full" disabled={creating} onClick={createUser}>{creating?"...":"Crear"}</button></div>
        </div>
        {msg && <div className="text-sm text-gray-600 mt-2">{msg}</div>}
      </div>

      <div className="card overflow-auto">
        <h2 className="text-lg font-semibold mb-3">Usuarios</h2>
        <table className="min-w-full">
          <thead className="bg-gray-100">
            <tr>
              <th className="table-th">Email</th>
              <th className="table-th">Rol</th>
              <th className="table-th">Descuento %</th>
              <th className="table-th">Activo</th>
              <th className="table-th">Nueva contraseña</th>
              <th className="table-th">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {items.map(r=>(
              <tr key={r.id} className="border-b">
                <td className="table-td">
                  <input className="input w-64" defaultValue={r.email} onChange={e=>setEdit(r.id,{ email: e.target.value })} />
                </td>
                <td className="table-td">
                  <select className="input w-28" defaultValue={r.role} onChange={e=>setEdit(r.id,{ role: e.target.value as any })}>
                    <option value="user">user</option>
                    <option value="admin">admin</option>
                  </select>
                </td>
                <td className="table-td">
                  <input className="input w-24" type="number" step="0.01" defaultValue={r.descuentoPct} onChange={e=>setEdit(r.id,{ descuentoPct: parseFloat(e.target.value||"0") })} />
                </td>
                <td className="table-td">
                  <input type="checkbox" defaultChecked={r.isActive} onChange={e=>setEdit(r.id,{ isActive: e.target.checked })} />
                </td>
                <td className="table-td">
                  <input className="input w-48" type="password" placeholder="Nueva contraseña" onChange={e=>setEdit(r.id,{ newPassword: e.target.value })} />
                </td>
                <td className="table-td">
                  <button className="btn btn-ghost" onClick={()=>saveRow(r)}>Guardar</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
'@
WriteNoBom (Join-Path $frontend 'src\pages\Users.tsx') $usersTsx

Write-Host 'Listo. Pasos:'
Write-Host '1) Backend: cd backend ; npm run dev'
Write-Host '2) Frontend: cd frontend ; npm run dev'
Write-Host 'Abrir http://localhost:5173 y probar Usuarios (editar/reset).'
