interface ImportMetaEnv {
  VITE_API_BASE_URL?: string;
}

// Augment the global ImportMeta interface
declare global {
  interface ImportMeta {
    readonly env: ImportMetaEnv;
  }
}

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'https://soundtec-buscador.onrender.com';
// axios.create({ baseURL: API_BASE, ... })


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

  // ---- Crear usuario (ruta pÃºblica previa)
  async createUser(data: { email: string; password: string; descuentoPct?: number; role?: "admin"|"user" }) {
    return request("/users", { method: "POST", body: JSON.stringify(data) });
  }
};
