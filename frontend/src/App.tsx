// frontend/src/App.tsx
// Header con logo (sin título), PageTitle debajo, navegación completa y footer azul oscuro.
// Incluye SuppliersPage e ImportXlsxPage mínimas. NO crea otro <Router>.

import { Routes, Route, NavLink, Navigate, useNavigate, useLocation } from "react-router-dom";
import { useEffect, useState } from "react";
import Products from "./pages/Products";
import Users from "./pages/Users";
import { api } from "./lib/api";

// Paleta
const BRAND = {
  primary: "#0A3D5D",
  primaryLight: "#EAF2F7",
  footerBg: "#06283D",
  footerText: "#E6F0F6",
};

const linkBase = "px-3 py-2 rounded-md text-sm font-medium transition";
const linkActive = (isActive: boolean) =>
  `${linkBase} ${isActive ? "bg-[color:var(--brand-primaryLight)] text-[color:var(--brand-primary)]" : "hover:bg-gray-100"}`;

function useResolvedLogo() {
  const [src, setSrc] = useState<string | null>(null);
  useEffect(() => {
    const candidates = ["/logo.png", "/logo_soundtec.png", "/logo.svg", "/assets/logo.png"];
    let cancelled = false;
    const tryNext = (i: number) => {
      if (cancelled || i >= candidates.length) return;
      const url = `${candidates[i]}?v=${Date.now()}`;
      const img = new Image();
      img.onload = () => !cancelled && setSrc(candidates[i]);
      img.onerror = () => tryNext(i + 1);
      img.src = url;
    };
    tryNext(0);
    return () => { cancelled = true; };
  }, []);
  return src;
}

function Header() {
  const logo = useResolvedLogo();

  // Login inline
  const [email, setEmail] = useState("");
  const [pass, setPass] = useState("");
  const [user, setUser] = useState<any>(null);
  const [err, setErr] = useState<string | null>(null);
  const nav = useNavigate();

  async function refreshMe() {
    try { const me = await api.me(); setUser((me as any).user); }
    catch { setUser(null); }
  }
  useEffect(() => { refreshMe(); }, []);

  async function onLogin(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    try {
      const r = await api.login(email.trim(), pass);
      localStorage.setItem("token", r.token);
      setEmail(""); setPass("");
      await refreshMe();
      nav("/");
    } catch (e: any) { setErr(e.message || "Error de login"); }
  }
  function logout() { localStorage.removeItem("token"); setUser(null); nav("/"); }

  return (
    <header
      className="w-full border-b bg-white"
      style={{
        ["--brand-primary" as any]: BRAND.primary,
        ["--brand-primaryLight" as any]: BRAND.primaryLight,
      }}
    >
      <div style={{ background: BRAND.primary, height: 3 }} />
      <div className="max-w-7xl mx-auto px-4 py-3 flex items-center gap-4">
        {/* Logo solo (sin título) */}
        <div className="flex items-center gap-3">
          {logo ? (
            <img src={logo} alt="Soundtec" className="h-12 w-auto object-contain" />
          ) : (
            <div className="h-12 w-48 bg-gray-200 animate-pulse rounded" />
          )}
        </div>

        {/* Navegación */}
        <nav className="ml-6 flex items-center gap-1">
          <NavLink to="/" end className={({isActive}) => linkActive(isActive)}>Productos</NavLink>
          {user?.role === "admin" && (
            <>
              <NavLink to="/suppliers" className={({isActive}) => linkActive(isActive)}>Proveedores</NavLink>
              <NavLink to="/import" className={({isActive}) => linkActive(isActive)}>Importar XLSX</NavLink>
              <NavLink to="/users" className={({isActive}) => linkActive(isActive)}>Usuarios</NavLink>
            </>
          )}
        </nav>

        {/* Login / usuario */}
        <div className="ml-auto">
          {user ? (
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-600">{user.email} · <span className="uppercase">{user.role}</span></span>
              <button className="btn btn-ghost" onClick={logout}>Salir</button>
            </div>
          ) : (
            <form onSubmit={onLogin} className="flex items-end gap-2">
              <div>
                <label className="label">Email</label>
                <input className="input h-9" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="admin@example.com" />
              </div>
              <div>
                <label className="label">Contraseña</label>
                <input className="input h-9" type="password" value={pass} onChange={(e) => setPass(e.target.value)} placeholder="•••••••" />
              </div>
              <button className="btn btn-primary h-9 mt-[22px]">Entrar</button>
              {err && <span className="text-xs text-red-600">{err}</span>}
            </form>
          )}
        </div>
      </div>
    </header>
  );
}

function PageTitle() {
  const { pathname } = useLocation();
  const map: Record<string, string> = {
    "/": "Lista de precios",
    "/suppliers": "Proveedores",
    "/import": "Importar XLSX",
    "/users": "Usuarios",
  };
  const title = map[pathname] ?? "";
  if (!title) return null;
  return (
    <div className="max-w-7xl mx-auto px-4 pt-4 pb-2">
      <h1 className="text-2xl font-semibold" style={{ color: BRAND.primary }}>{title}</h1>
    </div>
  );
}

function Footer() {
  return (
    <footer className="w-full" style={{ background: BRAND.footerBg }}>
      <div className="max-w-7xl mx-auto px-4 py-8 flex items-center justify-between">
        <span className="text-lg" style={{ color: BRAND.footerText }}>
          © {new Date().getFullYear()} Soundtec
        </span>
        <a
          href="https://soundtec.com.ar"
          target="_blank"
          rel="noreferrer"
          className="text-lg hover:underline"
          style={{ color: BRAND.footerText }}
        >
          soundtec.com.ar
        </a>
      </div>
    </footer>
  );
}

function RequireAdmin({ children }: { children: React.ReactNode }) {
  const [role, setRole] = useState<string | null>(null);
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    (async () => {
      try { const me = await api.me(); setRole((me as any).user?.role || null); }
      catch { setRole(null); }
      finally { setChecked(true); }
    })();
  }, []);

  if (!checked) return <div className="p-6">Cargando…</div>;
  if (role !== "admin") return <Navigate to="/" replace />;
  return <>{children}</>;
}

/* ----------------- Páginas mínimas si no existen ------------------ */
function SuppliersPage() {
  const [items, setItems] = useState<any[]>([]);
  const [name, setName] = useState("");
  const [website, setWebsite] = useState("");
  const [isCrestron, setIsCrestron] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function load() {
    try { const data = await api.listSuppliers(); setItems((data as any).items || data); }
    catch (e: any) { setMsg(e.message || "Error al cargar proveedores"); }
  }
  useEffect(() => { load(); }, []);

  async function create() {
    setMsg(null);
    try {
      await api.createSupplier({ name, websiteUrl: website, isCrestron });
      setName(""); setWebsite(""); setIsCrestron(false);
      await load(); setMsg("Proveedor creado.");
    } catch (e: any) { setMsg(e.message || "No se pudo crear"); }
  }

  return (
    <div className="space-y-6">
      <div className="card">
        <h2 className="text-lg font-semibold mb-3">Crear proveedor</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
          <div><label className="label">Nombre</label><input className="input mt-1" value={name} onChange={e=>setName(e.target.value)} /></div>
          <div><label className="label">Website</label><input className="input mt-1" value={website} onChange={e=>setWebsite(e.target.value)} /></div>
          <div className="flex items-end gap-2">
            <label className="label">Crestron</label>
            <input type="checkbox" className="ml-2" checked={isCrestron} onChange={e=>setIsCrestron(e.target.checked)} />
          </div>
          <div className="flex items-end"><button className="btn btn-primary w-full" onClick={create}>Crear</button></div>
        </div>
        {msg && <div className="text-sm text-gray-600 mt-2">{msg}</div>}
      </div>

      <div className="card overflow-auto">
        <h2 className="text-lg font-semibold mb-3">Proveedores</h2>
        <table className="min-w-full">
          <thead className="bg-gray-100">
            <tr><th className="table-th">Nombre</th><th className="table-th">Website</th><th className="table-th">Crestron</th></tr>
          </thead>
          <tbody>
            {items.map((s:any)=>(
              <tr key={s.id} className="border-b">
                <td className="table-td">{s.name}</td>
                <td className="table-td"><a className="text-sky-700 hover:underline" href={s.websiteUrl} target="_blank" rel="noreferrer">{s.websiteUrl || "-"}</a></td>
                <td className="table-td">{s.isCrestron ? "Sí" : "No"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function ImportXlsxPage() {
  const [file, setFile] = useState<File | null>(null);
  const [supplierName, setSupplierName] = useState("");
  const [sourceLabel, setSourceLabel] = useState("Excel Crestron");
  const [msg, setMsg] = useState<string | null>(null);

  async function submit() {
    if (!file) { setMsg("Seleccioná un archivo .xlsx"); return; }
    if (!supplierName) { setMsg("Ingresá el nombre del proveedor"); return; }
    setMsg(null);
    try {
      const res = await api.importXlsx(file, supplierName, sourceLabel);
      setMsg(`Importado OK · ${res.imported} productos · Lista: ${res.priceList?.id || "-"}`);
    } catch (e: any) { setMsg(e.message || "Error al importar"); }
  }

  return (
    <div className="card">
      <h2 className="text-lg font-semibold mb-3">Importar XLSX</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3 items-end">
        <div><label className="label">Proveedor (nombre)</label><input className="input mt-1" value={supplierName} onChange={e=>setSupplierName(e.target.value)} placeholder="Crestron" /></div>
        <div><label className="label">Etiqueta origen</label><input className="input mt-1" value={sourceLabel} onChange={e=>setSourceLabel(e.target.value)} /></div>
        <div><label className="label">Archivo .xlsx</label><input className="input mt-1" type="file" accept=".xlsx" onChange={e=>setFile(e.target.files?.[0]||null)} /></div>
      </div>
      <div className="mt-4 flex gap-2">
        <button className="btn btn-primary" onClick={submit}>Importar</button>
        {msg && <span className="text-sm text-gray-700">{msg}</span>}
      </div>
    </div>
  );
}
/* ------------------------------------------------------------------ */

export default function App() {
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--brand-primary", BRAND.primary);
    root.style.setProperty("--brand-primaryLight", BRAND.primaryLight);
  }, []);

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <Header />
      <PageTitle />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-4 py-6">
          <Routes>
            <Route path="/" element={<Products />} />
            <Route path="/users" element={<RequireAdmin><Users /></RequireAdmin>} />
            <Route path="/suppliers" element={<RequireAdmin><SuppliersPage /></RequireAdmin>} />
            <Route path="/import" element={<RequireAdmin><ImportXlsxPage /></RequireAdmin>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </div>
      </main>
      <Footer />
    </div>
  );
}
