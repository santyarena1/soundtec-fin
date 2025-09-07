# frontend-setup.ps1
# Frontend React + Vite + TS + Tailwind, conectado a tu backend.
# Rutas: /login, /products, /suppliers, /import-xlsx, /users
# Editor rápido de MarkUp/Impuestos/IVA (admin) vía /priceitems/:id

$ErrorActionPreference = 'Stop'
$root = Get-Location
$front = Join-Path $root 'frontend'

if (Test-Path $front) {
  Write-Host "⚠️  Ya existe 'frontend'. Borrala o renombrala si querés recrear." -ForegroundColor Yellow
  exit 1
}

New-Item -ItemType Directory -Force -Path $front | Out-Null

function W { param($path, $content)
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $content | Out-File -FilePath $path -Encoding utf8 -Force
}

# ---------------- package.json ----------------
W "$front\package.json" @'
{
  "name": "frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite --open",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.5",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.41",
    "tailwindcss": "^3.4.10",
    "typescript": "^5.5.4",
    "vite": "^5.4.10",
    "@vitejs/plugin-react": "^4.3.2"
  }
}
'@

# ---------------- tsconfig.json ----------------
W "$front\tsconfig.json" @'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "jsx": "react-jsx",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "strict": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
'@

# ---------------- vite.config.ts ----------------
W "$front\vite.config.ts" @'
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
export default defineConfig({
  plugins: [react()]
})
'@

# ---------------- postcss & tailwind ----------------
W "$front\postcss.config.js" @'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
'@
W "$front\tailwind.config.js" @'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      boxShadow: {
        card: '0 10px 20px rgba(0,0,0,0.04), 0 6px 6px rgba(0,0,0,0.06)'
      }
    },
  },
  plugins: [],
}
'@

# ---------------- index.html ----------------
W "$front\index.html" @'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>Sistema de Listas de Precios</title>
  </head>
  <body class="bg-gray-50">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
'@

# ---------------- env example ----------------
W "$front\.env.example" @'
VITE_API_URL=https://soundtec-buscador.onrender.com

'@

# ---------------- styles ----------------
W "$front\src\index.css" @'
@tailwind base;
@tailwind components;
@tailwind utilities;

.container { @apply max-w-7xl mx-auto px-4; }
.card { @apply bg-white rounded-2xl shadow-card p-5; }
.btn { @apply inline-flex items-center justify-center rounded-md px-4 py-2 border text-sm; }
.btn-primary { @apply bg-blue-600 text-white border-blue-600 hover:bg-blue-700; }
.btn-ghost { @apply border-gray-300 bg-white hover:bg-gray-50; }
.input { @apply border border-gray-300 rounded-md px-3 py-2 w-full; }
.label { @apply text-sm text-gray-600; }
.table-th { @apply text-left p-2 text-sm font-semibold text-gray-700 bg-gray-100; }
.table-td { @apply p-2 text-sm; }
.badge { @apply inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-700; }
'@

# ---------------- main.tsx ----------------
W "$front\src\main.tsx" @'
import React from "react"
import ReactDOM from "react-dom/client"
import { BrowserRouter } from "react-router-dom"
import App from "./App"
import "./index.css"
import { AuthProvider } from "./lib/auth"

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
)
'@

# ---------------- App.tsx ----------------
W "$front\src\App.tsx" @'
import { Navigate, Route, Routes } from "react-router-dom"
import Login from "./pages/Login"
import Products from "./pages/Products"
import Suppliers from "./pages/Suppliers"
import ImportXlsx from "./pages/ImportXlsx"
import Users from "./pages/Users"
import Navbar from "./components/Navbar"
import { useAuth } from "./lib/auth"

function Protected({ children }: { children: JSX.Element }) {
  const { token } = useAuth()
  if (!token) return <Navigate to="/login" replace />
  return children
}
function AdminOnly({ children }: { children: JSX.Element }) {
  const { user } = useAuth()
  if (!user || user.role !== "admin") return <Navigate to="/" replace />
  return children
}

export default function App() {
  const { token } = useAuth()
  return (
    <div className="min-h-screen">
      {token && <Navbar />}
      <div className="container py-4">
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<Protected><Products /></Protected>} />
          <Route path="/products" element={<Protected><Products /></Protected>} />
          <Route path="/suppliers" element={<Protected><AdminOnly><Suppliers /></AdminOnly></Protected>} />
          <Route path="/import-xlsx" element={<Protected><AdminOnly><ImportXlsx /></AdminOnly></Protected>} />
          <Route path="/users" element={<Protected><AdminOnly><Users /></AdminOnly></Protected>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </div>
  )
}
'@

# ---------------- lib/api.ts ----------------
W "$front\src\lib\api.ts" @'
const API_BASE = (import.meta as any).env?.VITE_API_URL=https://soundtec-buscador.onrender.com


function getToken() {
  try { return localStorage.getItem("token") } catch { return null }
}

async function request(path: string, opts: RequestInit = {}, auth = true) {
  const token = getToken()
  const headers: any = {}
  if (!(opts.body instanceof FormData)) headers["Content-Type"] = "application/json"
  if (auth && token) headers["Authorization"] = `Bearer ${token}`
  const res = await fetch(`${API_BASE}${path}`, { ...opts, headers: { ...headers, ...(opts.headers || {}) } })
  if (!res.ok) {
    let msg = ""
    try { msg = await res.text() } catch {}
    throw new Error(msg || `HTTP ${res.status}`)
  }
  const ct = res.headers.get("content-type") || ""
  if (ct.includes("application/json")) return res.json()
  return res.text()
}

export const api = {
  // Auth
  async login(email: string, password: string): Promise<{ token: string, user: any }> {
    return request("/auth/login", { method: "POST", body: JSON.stringify({ email, password }) }, false)
  },
  async me(): Promise<{ user: any }> {
    return request("/auth/me")
  },

  // Products
  async listProducts(params: { q?: string; page?: number; pageSize?: number } = {}) {
    const sp = new URLSearchParams()
    if (params.q) sp.append("q", params.q)
    if (params.page) sp.append("page", String(params.page))
    if (params.pageSize) sp.append("pageSize", String(params.pageSize))
    return request(`/products${sp.toString() ? `?${sp}` : ""}`)
  },

  // PriceItems (admin)
  async updatePriceItem(id: string, data: { basePriceUsd?: number; markupPct?: number; impuestosPct?: number; ivaPct?: number; }) {
    return request(`/priceitems/${id}`, { method: "PATCH", body: JSON.stringify(data) })
  },

  // Suppliers (admin)
  async listSuppliers() { return request("/suppliers") },
  async createSupplier(data: { name: string; slug?: string; websiteUrl?: string; isCrestron?: boolean }) {
    return request("/suppliers", { method: "POST", body: JSON.stringify(data) })
  },

  // Import XLSX (admin)
  async importXlsx(file: File, supplierName: string, sourceLabel: string) {
    const form = new FormData()
    form.append("file", file)
    const sp = new URLSearchParams({ supplierName, sourceLabel, rawCurrency: "USD" })
    const token = getToken()
    const res = await fetch(`${API_BASE}/pricelists/import-xlsx?${sp.toString()}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token || ""}` },
      body: form
    })
    if (!res.ok) throw new Error(await res.text())
    return res.json()
  },

  // Users (admin)
  async listUsers() { return request("/users") },
  async createUser(data: { email: string; password: string; descuentoPct?: number; role?: "admin"|"user" }) {
    return request("/users", { method: "POST", body: JSON.stringify(data) })
  },
  async updateUser(id: string, data: { descuentoPct?: number; isActive?: boolean }) {
    return request(`/users/${id}`, { method: "PATCH", body: JSON.stringify(data) })
  }
}
'@

# ---------------- lib/auth.tsx ----------------
W "$front\src\lib\auth.tsx" @'
import { createContext, useContext, useEffect, useState } from "react"
import { api } from "./api"

type User = { id: string; email: string; role: "admin"|"user"; descuentoPct: number }

type AuthState = {
  token: string | null
  user: User | null
  setToken: (t: string | null) => void
  setUser: (u: User | null) => void
}

const AuthContext = createContext<AuthState>({
  token: null, user: null, setToken: ()=>{}, setUser: ()=>{}
})

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem("token"))
  const [user, setUser] = useState<User | null>(() => {
    const raw = localStorage.getItem("user")
    return raw ? JSON.parse(raw) : null
  })

  useEffect(() => { if (token) localStorage.setItem("token", token); else localStorage.removeItem("token") }, [token])
  useEffect(() => { if (user) localStorage.setItem("user", JSON.stringify(user)); else localStorage.removeItem("user") }, [user])

  useEffect(() => {
    if (!token) return
    api.me().then((res: any) => setUser(res.user)).catch(()=>{})
  }, [token])

  return <AuthContext.Provider value={{ token, user, setToken, setUser }}>{children}</AuthContext.Provider>
}

export function useAuth() { return useContext(AuthContext) }
export function logout() { localStorage.removeItem("token"); localStorage.removeItem("user"); location.href = "/login" }
'@

# ---------------- components/Navbar.tsx ----------------
W "$front\src\components\Navbar.tsx" @'
import { Link, NavLink } from "react-router-dom"
import { useAuth, logout } from "../lib/auth"

export default function Navbar() {
  const { user } = useAuth()
  const link = (to: string, label: string) => (
    <NavLink to={to} className={({isActive})=>`px-3 py-2 rounded-md ${isActive?"bg-blue-50 text-blue-700":"text-gray-700 hover:bg-gray-100"}`}>{label}</NavLink>
  )
  return (
    <div className="bg-white border-b">
      <div className="container py-3 flex items-center justify-between">
        <Link to="/" className="text-lg font-semibold">Listas de Precios</Link>
        <nav className="flex gap-1">
          {link("/products","Productos")}
          {user?.role==="admin" && link("/suppliers","Proveedores")}
          {user?.role==="admin" && link("/import-xlsx","Importar XLSX")}
          {user?.role==="admin" && link("/users","Usuarios")}
        </nav>
        <div className="flex items-center gap-3 text-sm text-gray-600">
          <span className="hidden sm:block">{user?.email} {user && `(${user.role})`}</span>
          <button className="btn btn-ghost" onClick={logout}>Salir</button>
        </div>
      </div>
    </div>
  )
}
'@

# ---------------- pages/Login.tsx ----------------
W "$front\src\pages\Login.tsx" @'
import { useState } from "react"
import { useNavigate } from "react-router-dom"
import { api } from "../lib/api"
import { useAuth } from "../lib/auth"

export default function Login() {
  const nav = useNavigate()
  const { setToken, setUser } = useAuth()
  const [email, setEmail] = useState("admin@example.com")
  const [password, setPassword] = useState("admin123")
  const [err, setErr] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    setErr(null); setLoading(true)
    try {
      const data = await api.login(email, password)
      setToken(data.token)
      setUser(data.user)
      nav("/products", { replace: true })
    } catch (e: any) {
      setErr(e.message || "Error de login")
    } finally { setLoading(false) }
  }

  return (
    <div className="container">
      <div className="max-w-md mx-auto mt-24 card">
        <h1 className="text-xl font-semibold mb-4">Ingresar</h1>
        <form onSubmit={onSubmit} className="space-y-3">
          <div>
            <label className="label">Email</label>
            <input className="input mt-1" value={email} onChange={e=>setEmail(e.target.value)} />
          </div>
          <div>
            <label className="label">Password</label>
            <input className="input mt-1" type="password" value={password} onChange={e=>setPassword(e.target.value)} />
          </div>
          {err && <div className="text-red-600 text-sm">{err}</div>}
          <button className="btn btn-primary w-full" disabled={loading}>{loading?"...":"Entrar"}</button>
        </form>
      </div>
    </div>
  )
}
'@

# ---------------- pages/Products.tsx ----------------
W "$front\src\pages\Products.tsx" @'
import { useEffect, useMemo, useState } from "react"
import { api } from "../lib/api"
import { useAuth } from "../lib/auth"

type Product = {
  id: string
  code: string
  name: string
  brand?: string | null
  family?: string | null
  stockMiami?: number | null
  stockLaredo?: number | null
  supplier?: { id: string; name: string }
  pricing?: {
    priceItemId?: string
    basePriceUsd: number
    markupPct: number
    impuestosPct: number
    ivaPct: number
    finalAdminUsd: number
    priceForUserUsd: number
    effectiveDate: string
  } | null
}

export default function Products() {
  const { user } = useAuth()
  const isAdmin = user?.role === "admin"
  const [q, setQ] = useState("")
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(50)
  const [total, setTotal] = useState(0)
  const [items, setItems] = useState<Product[]>([])
  const [loading, setLoading] = useState(false)

  const [editTarget, setEditTarget] = useState<{ id: string; name: string; priceItemId: string; markupPct: number; impuestosPct: number; ivaPct: number } | null>(null)
  const canEdit = useMemo(()=> isAdmin && !!editTarget?.priceItemId, [isAdmin, editTarget])

  async function load() {
    setLoading(true)
    try {
      const res = await api.listProducts({ q, page, pageSize }) as any
      setItems(res.items)
      setTotal(res.total)
    } finally { setLoading(false) }
  }

  useEffect(()=>{ load() }, [page, pageSize]) // eslint-disable-line

  function openEdit(p: Product) {
    if (!p.pricing?.priceItemId) return
    setEditTarget({
      id: p.id,
      name: p.name,
      priceItemId: p.pricing.priceItemId,
      markupPct: p.pricing.markupPct,
      impuestosPct: p.pricing.impuestosPct,
      ivaPct: p.pricing.ivaPct
    })
  }

  async function saveEdit(e: React.FormEvent) {
    e.preventDefault()
    if (!editTarget) return
    await api.updatePriceItem(editTarget.priceItemId, {
      markupPct: editTarget.markupPct,
      impuestosPct: editTarget.impuestosPct,
      ivaPct: editTarget.ivaPct
    })
    setEditTarget(null)
    load()
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row gap-3 items-end">
        <div className="flex-1">
          <label className="label">Buscar</label>
          <input className="input mt-1" placeholder="código, nombre, marca..." value={q} onChange={e=>setQ(e.target.value)} />
        </div>
        <button className="btn btn-primary" onClick={()=>{ setPage(1); load() }}>Buscar</button>
        <div className="ml-auto text-sm text-gray-600">Total: {total}</div>
      </div>

      {canEdit && (
        <div className="card">
          <form onSubmit={saveEdit} className="grid grid-cols-1 md:grid-cols-5 gap-3 items-end">
            <div className="md:col-span-5"><div className="badge">Editando: {editTarget?.name}</div></div>
            <div><label className="label">MarkUp %</label><input className="input mt-1" type="number" step="0.01" value={editTarget!.markupPct} onChange={e=>setEditTarget(s=>s?{...s, markupPct: parseFloat(e.target.value||"0")}:s)} /></div>
            <div><label className="label">Impuestos %</label><input className="input mt-1" type="number" step="0.01" value={editTarget!.impuestosPct} onChange={e=>setEditTarget(s=>s?{...s, impuestosPct: parseFloat(e.target.value||"0")}:s)} /></div>
            <div><label className="label">IVA %</label><input className="input mt-1" type="number" step="0.01" value={editTarget!.ivaPct} onChange={e=>setEditTarget(s=>s?{...s, ivaPct: parseFloat(e.target.value||"0")}:s)} /></div>
            <div className="flex gap-2">
              <button className="btn btn-primary">Guardar</button>
              <button type="button" className="btn btn-ghost" onClick={()=>setEditTarget(null)}>Cancelar</button>
            </div>
          </form>
        </div>
      )}

      <div className="card overflow-auto">
        <table className="min-w-full">
          <thead>
            <tr>
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
            {items.map(p=>(
              <tr key={p.id} className="border-b">
                <td className="table-td font-mono">{p.code}</td>
                <td className="table-td">{p.name}</td>
                <td className="table-td">{p.brand || "-"}</td>
                <td className="table-td">{p.family || "-"}</td>
                <td className="table-td">{p.supplier?.name || "-"}</td>
                <td className="table-td text-right">{p.pricing?.finalAdminUsd?.toFixed(2) ?? "-"}</td>
                <td className="table-td text-right font-semibold">{p.pricing?.priceForUserUsd?.toFixed(2) ?? "-"}</td>
                <td className="table-td text-center">{p.stockMiami ?? "-"} M / {p.stockLaredo ?? "-"} L</td>
                <td className="table-td text-center">
                  {isAdmin && p.pricing?.priceItemId ? (
                    <button className="btn btn-ghost" onClick={()=>openEdit(p)}>Editar</button>
                  ) : <span className="text-gray-400">-</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex items-center gap-3">
        <button className="btn btn-ghost" onClick={()=>setPage(p=>Math.max(1, p-1))}>Anterior</button>
        <div>Página {page}</div>
        <button className="btn btn-ghost" onClick={()=> setPage(p=> p*pageSize < total ? p+1 : p)}>Siguiente</button>
        <select className="input w-28" value={pageSize} onChange={e=>{ setPageSize(parseInt(e.target.value)); setPage(1) }}>
          <option value={25}>25</option>
          <option value={50}>50</option>
          <option value={100}>100</option>
        </select>
      </div>
    </div>
  )
}
'@

# ---------------- pages/Suppliers.tsx ----------------
W "$front\src\pages\Suppliers.tsx" @'
import { useEffect, useState } from "react"
import { api } from "../lib/api"

export default function Suppliers() {
  const [items, setItems] = useState<any[]>([])
  const [name, setName] = useState("Crestron")
  const [slug, setSlug] = useState("crestron")
  const [websiteUrl, setWebsiteUrl] = useState("https://www.crestron.com")
  const [isCrestron, setIsCrestron] = useState(true)

  async function load() { const data = await api.listSuppliers(); setItems((data as any).items) }
  useEffect(()=>{ load() }, [])

  async function createSupplier() {
    await api.createSupplier({ name, slug, websiteUrl, isCrestron })
    setName(""); setSlug(""); setWebsiteUrl(""); setIsCrestron(false)
    load()
  }

  return (
    <div className="space-y-6">
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Crear proveedor</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
          <div><label className="label">Nombre</label><input className="input mt-1" value={name} onChange={e=>setName(e.target.value)} /></div>
          <div><label className="label">Slug</label><input className="input mt-1" value={slug} onChange={e=>setSlug(e.target.value)} /></div>
          <div><label className="label">Website</label><input className="input mt-1" value={websiteUrl} onChange={e=>setWebsiteUrl(e.target.value)} /></div>
          <div className="flex items-end gap-2">
            <label className="label">Es Crestron</label>
            <input type="checkbox" className="mt-1" checked={isCrestron} onChange={e=>setIsCrestron(e.target.checked)} />
          </div>
        </div>
        <div className="mt-3"><button className="btn btn-primary" onClick={createSupplier}>Crear</button></div>
      </div>

      <div className="card overflow-auto">
        <h2 className="text-lg font-semibold mb-3">Proveedores</h2>
        <table className="min-w-full">
          <thead><tr><th className="table-th">Nombre</th><th className="table-th">Slug</th><th className="table-th">Website</th><th className="table-th">Crestron</th></tr></thead>
          <tbody>
            {items.map((s:any)=>(
              <tr key={s.id} className="border-b">
                <td className="table-td">{s.name}</td>
                <td className="table-td">{s.slug || "-"}</td>
                <td className="table-td"><a className="text-blue-600" href={s.websiteUrl || "#"} target="_blank">{s.websiteUrl || "-"}</a></td>
                <td className="table-td">{s.isCrestron ? "Sí" : "No"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
'@

# ---------------- pages/ImportXlsx.tsx ----------------
W "$front\src\pages\ImportXlsx.tsx" @'
import { useState } from "react"
import { api } from "../lib/api"

export default function ImportXlsx() {
  const [supplierName, setSupplierName] = useState("Crestron")
  const [sourceLabel, setSourceLabel] = useState("Excel Crestron Demo")
  const [file, setFile] = useState<File | null>(null)
  const [result, setResult] = useState<any>(null)
  const [err, setErr] = useState<string | null>(null)

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    setErr(null); setResult(null)
    if (!file) return setErr("Selecciona un archivo XLSX")
    try {
      const res = await api.importXlsx(file, supplierName, sourceLabel)
      setResult(res)
    } catch (e:any) { setErr(e.message) }
  }

  return (
    <div className="space-y-4">
      <div className="card">
        <h2 className="text-lg font-semibold mb-4">Importar XLSX</h2>
        <form onSubmit={onSubmit} className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><label className="label">Supplier name</label><input className="input mt-1" value={supplierName} onChange={e=>setSupplierName(e.target.value)} /></div>
            <div><label className="label">Source label</label><input className="input mt-1" value={sourceLabel} onChange={e=>setSourceLabel(e.target.value)} /></div>
            <div><label className="label">Archivo XLSX</label><input className="input mt-1" type="file" accept=".xlsx,.xls" onChange={e=>setFile(e.target.files?.[0] || null)} /></div>
          </div>
          <button className="btn btn-primary">Importar</button>
        </form>
      </div>

      {err && <div className="card text-red-600 text-sm whitespace-pre-wrap">{err}</div>}
      {result && (
        <div className="card text-sm">
          <div className="font-semibold mb-2">Resultado</div>
          <pre className="overflow-auto">{JSON.stringify(result, null, 2)}</pre>
        </div>
      )}
    </div>
  )
}
'@

# ---------------- pages/Users.tsx ----------------
W "$front\src\pages\Users.tsx" @'
import { useEffect, useState } from "react"
import { api } from "../lib/api"

export default function Users() {
  const [items, setItems] = useState<any[]>([])
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [descuentoPct, setDescuentoPct] = useState(0)
  const [role, setRole] = useState<"admin"|"user">("user")
  const [msg, setMsg] = useState<string | null>(null)

  async function load() { const data = await api.listUsers(); setItems((data as any).items) }
  useEffect(()=>{ load() }, [])

  async function createUser() {
    setMsg(null)
    try {
      await api.createUser({ email, password, descuentoPct, role })
      setEmail(""); setPassword(""); setDescuentoPct(0); setRole("user")
      load(); setMsg("Usuario creado")
    } catch (e:any) { setMsg(e.message) }
  }

  async function updateDiscount(id: string, pct: number) {
    await api.updateUser(id, { descuentoPct: pct })
    load()
  }

  return (
    <div className="space-y-6">
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Crear usuario</h2>
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          <div><label className="label">Email</label><input className="input mt-1" value={email} onChange={e=>setEmail(e.target.value)} /></div>
          <div><label className="label">Password</label><input className="input mt-1" type="password" value={password} onChange={e=>setPassword(e.target.value)} /></div>
          <div><label className="label">Descuento %</label><input className="input mt-1" type="number" value={descuentoPct} onChange={e=>setDescuentoPct(parseFloat(e.target.value||"0"))} /></div>
          <div>
            <label className="label">Rol</label>
            <select className="input mt-1" value={role} onChange={e=>setRole(e.target.value as any)}>
              <option value="user">user</option>
              <option value="admin">admin</option>
            </select>
          </div>
          <div className="flex items-end"><button className="btn btn-primary w-full" onClick={createUser}>Crear</button></div>
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
              <th className="table-th">Creado</th>
            </tr>
          </thead>
          <tbody>
            {items.map((u:any)=>(
              <tr key={u.id} className="border-b">
                <td className="table-td">{u.email}</td>
                <td className="table-td">{u.role}</td>
                <td className="table-td">
                  <input type="number" className="input w-24" defaultValue={u.descuentoPct} onBlur={(e)=>updateDiscount(u.id, parseFloat(e.target.value||"0"))} />
                </td>
                <td className="table-td">{u.isActive ? "Sí" : "No"}</td>
                <td className="table-td">{new Date(u.createdAt).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
'@

Write-Host "✅ Frontend creado en 'frontend'."
Write-Host "Siguiente:"
Write-Host "  cd frontend"
Write-Host "  npm install"
Write-Host "  copy .env.example .env   (o editar VITE_API_BASE)"
Write-Host "  npm run dev"
