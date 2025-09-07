// frontend/src/pages/Users.tsx
// Gestión de usuarios (admin):
// - Listado con edición inline: email, rol, descuento %, activo
// - Guardar por fila (toasts + resaltado)
// - Reset de contraseña: manual o generar temporal (muestra 1 sola vez y permite copiar)
// - Crear usuario: admite password opcional; si no mandás, genera temporal (muestra y copia)
// - Sin dependencias externas (usa fetch con Authorization a partir del token del localStorage)

import { useEffect, useMemo, useState } from "react";

type Role = "admin" | "user";
type User = {
  id: string;
  email: string;
  role: Role;
  descuentoPct: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

const API_BASE: string =
  (import.meta as any).env?.VITE_API_BASE || "https://soundtec-buscador.onrender.com";

function authHeaders() {
  const t = localStorage.getItem("token");
  return {
    "Content-Type": "application/json",
    ...(t ? { Authorization: `Bearer ${t}` } : {}),
  };
}

async function listUsers(): Promise<{ items: User[] }> {
  const res = await fetch(`${API_BASE}/admin/users`, {
    headers: authHeaders(),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function createUser(payload: {
  email: string;
  role: Role;
  descuentoPct: number;
  isActive: boolean;
  password?: string;
}): Promise<{ user: User; temporaryPassword?: string }> {
  const res = await fetch(`${API_BASE}/admin/users`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(payload),
  });
  const txt = await res.text();
  if (!res.ok) throw new Error(safeErr(txt));
  return JSON.parse(txt);
}

async function updateUser(id: string, payload: Partial<Pick<User, "email" | "role" | "descuentoPct" | "isActive">>): Promise<User> {
  const res = await fetch(`${API_BASE}/admin/users/${id}`, {
    method: "PATCH",
    headers: authHeaders(),
    body: JSON.stringify(payload),
  });
  const txt = await res.text();
  if (!res.ok) throw new Error(safeErr(txt));
  return JSON.parse(txt);
}

async function resetPassword(id: string, newPassword?: string): Promise<{ ok: true; message: string; temporaryPassword?: string }> {
  const res = await fetch(`${API_BASE}/admin/users/${id}/reset-password`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(newPassword ? { newPassword } : {}),
  });
  const txt = await res.text();
  if (!res.ok) throw new Error(safeErr(txt));
  return JSON.parse(txt);
}

function safeErr(txt: string) {
  try {
    const j = JSON.parse(txt);
    return j?.error || j?.message || txt;
  } catch {
    return txt || "Error";
  }
}

function fmtDate(d: string) {
  try {
    return new Date(d).toLocaleString();
  } catch {
    return d;
  }
}

type Toast = { id: number; kind: "ok" | "err"; text: string };
let toastSeq = 1;

function useToasts() {
  const [toasts, setToasts] = useState<Toast[]>([]);
  function push(kind: "ok" | "err", text: string, ms = 3000) {
    const id = toastSeq++;
    setToasts((t) => [...t, { id, kind, text }]);
    if (ms > 0) setTimeout(() => dismiss(id), ms);
  }
  function dismiss(id: number) {
    setToasts((t) => t.filter((x) => x.id !== id));
  }
  return { toasts, push, dismiss };
}

export default function UsersPage() {
  const [items, setItems] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [lastSavedId, setLastSavedId] = useState<string | null>(null);

  // Estado de edición por fila (strings para evitar el “0” automático)
  type RowEdit = {
    email: string;
    role: Role;
    descuentoStr: string; // 0..100
    isActive: boolean;
    dirty?: boolean;
  };
  const [edits, setEdits] = useState<Record<string, RowEdit>>({});

  // Crear usuario
  const [newEmail, setNewEmail] = useState("");
  const [newRole, setNewRole] = useState<Role>("user");
  const [newDescuentoStr, setNewDescuentoStr] = useState("");
  const [newActive, setNewActive] = useState(true);
  const [newPass, setNewPass] = useState("");

  // Passwords temporales visibles (mostrar una sola vez)
  const [tempVisible, setTempVisible] = useState<Record<string, string>>({}); // id(or "new") -> temp password

  // Toaster
  const { toasts, push, dismiss } = useToasts();

  async function load() {
    setLoading(true);
    try {
      const data = await listUsers();
      setItems(data.items || []);
      // construir estado de edición
      const map: Record<string, RowEdit> = {};
      for (const u of data.items) {
        map[u.id] = {
          email: u.email,
          role: u.role,
          descuentoStr: String(u.descuentoPct ?? ""),
          isActive: !!u.isActive,
          dirty: false,
        };
      }
      setEdits(map);
    } catch (e: any) {
      push("err", e.message || "Error al cargar usuarios");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  function onEditChange(id: string, patch: Partial<RowEdit>) {
    setEdits((prev) => ({ ...prev, [id]: { ...prev[id], ...patch, dirty: true } }));
  }

  async function onSave(id: string) {
    const row = edits[id];
    if (!row) return;
    // validar y preparar payload
    const payload: any = {};
    // email
    if (row.email.trim() === "") return push("err", "Email no puede estar vacío");
    payload.email = row.email.trim().toLowerCase();
    // role
    payload.role = row.role;
    // descuento
    const n = Number(row.descuentoStr);
    if (!Number.isFinite(n) || n < 0 || n > 100) {
      return push("err", "Descuento debe ser un número entre 0 y 100");
    }
    payload.descuentoPct = Math.round(n * 100) / 100; // 2 decimales
    // activo
    payload.isActive = !!row.isActive;

    try {
      const updated = await updateUser(id, payload);
      // aplicar en UI
      setItems((prev) => prev.map((u) => (u.id === id ? updated : u)));
      setEdits((prev) => ({
        ...prev,
        [id]: {
          email: updated.email,
          role: updated.role,
          descuentoStr: String(updated.descuentoPct ?? ""),
          isActive: !!updated.isActive,
          dirty: false,
        },
      }));
      setLastSavedId(id);
      // Mensajes más claros según lo cambiado
      push("ok", "Cambios guardados");
    } catch (e: any) {
      push("err", e.message || "No se pudo guardar");
    }
  }

  async function onReset(id: string, mode: "manual" | "auto", manualText?: string) {
    try {
      const res = await resetPassword(id, mode === "manual" ? manualText : undefined);
      if (res.temporaryPassword) {
        setTempVisible((m) => ({ ...m, [id]: res.temporaryPassword! }));
        push("ok", "Contraseña temporal generada");
      } else {
        push("ok", "Contraseña cambiada");
      }
    } catch (e: any) {
      push("err", e.message || "No se pudo resetear");
    }
  }

  async function onCreate() {
    if (!newEmail.trim()) return push("err", "Email requerido");
    const desc = Number(newDescuentoStr);
    if (newDescuentoStr !== "" && (!Number.isFinite(desc) || desc < 0 || desc > 100)) {
      return push("err", "Descuento debe ser 0..100");
    }
    try {
      const res = await createUser({
        email: newEmail.trim().toLowerCase(),
        role: newRole,
        descuentoPct: Number.isFinite(desc) ? Math.round(desc * 100) / 100 : 0,
        isActive: newActive,
        password: newPass.trim() || undefined,
      });
      setNewEmail("");
      setNewRole("user");
      setNewDescuentoStr("");
      setNewActive(true);
      setNewPass("");
      // agregar al listado
      setItems((prev) => [res.user, ...prev]);
      setEdits((prev) => ({
        [res.user.id]: {
          email: res.user.email,
          role: res.user.role,
          descuentoStr: String(res.user.descuentoPct ?? ""),
          isActive: !!res.user.isActive,
          dirty: false,
        },
        ...prev,
      }));
      if (res.temporaryPassword) {
        setTempVisible((m) => ({ ...m, new: res.temporaryPassword! }));
        push("ok", "Usuario creado (se generó contraseña temporal)");
      } else {
        push("ok", "Usuario creado");
      }
    } catch (e: any) {
      push("err", e.message || "No se pudo crear el usuario");
    }
  }

  function copy(text: string) {
    navigator.clipboard?.writeText(text).then(
      () => push("ok", "Copiado"),
      () => push("err", "No se pudo copiar")
    );
  }

  const total = useMemo(() => items.length, [items]);

  return (
    <div className="space-y-6">
      {/* TOASTS */}
      <div className="fixed top-3 right-3 z-50 space-y-2">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={`px-3 py-2 rounded shadow text-sm ${
              t.kind === "ok" ? "bg-green-600 text-white" : "bg-red-600 text-white"
            }`}
            onClick={() => dismiss(t.id)}
            title="Click para cerrar"
          >
            {t.text}
          </div>
        ))}
      </div>

      {/* CREAR USUARIO */}
      <div className="card">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-semibold">Crear usuario</h2>
          <div className="text-sm text-gray-500">Total usuarios: {total}</div>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-6 gap-3 items-end">
          <div>
            <label className="label">Email</label>
            <input
              className="input mt-1"
              value={newEmail}
              onChange={(e) => setNewEmail(e.target.value)}
              placeholder="usuario@dominio.com"
            />
          </div>
          <div>
            <label className="label">Rol</label>
            <select
              className="input mt-1"
              value={newRole}
              onChange={(e) => setNewRole(e.target.value as Role)}
            >
              <option value="user">Usuario</option>
              <option value="admin">Administrador</option>
            </select>
          </div>
          <div>
            <label className="label">Descuento %</label>
            <input
              className="input mt-1"
              value={newDescuentoStr}
              onChange={(e) => setNewDescuentoStr(e.target.value)}
              inputMode="decimal"
              placeholder="0"
            />
          </div>
          <div className="flex items-end gap-2">
            <label className="label">Activo</label>
            <input
              type="checkbox"
              className="ml-2"
              checked={newActive}
              onChange={(e) => setNewActive(e.target.checked)}
            />
          </div>
          <div>
            <label className="label">Contraseña (opcional)</label>
            <input
              className="input mt-1"
              type="text"
              value={newPass}
              onChange={(e) => setNewPass(e.target.value)}
              placeholder="dejar vacío para generar"
            />
          </div>
          <div className="flex items-end">
            <button className="btn btn-primary w-full" onClick={onCreate}>
              Crear
            </button>
          </div>
        </div>

        {/* Si se generó temporal al crear */}
        {tempVisible.new && (
          <div className="mt-3 p-3 rounded bg-yellow-50 border border-yellow-200 flex items-center justify-between">
            <div>
              <div className="font-medium">Contraseña temporal generada</div>
              <div className="font-mono text-sm">{tempVisible.new}</div>
            </div>
            <div className="flex gap-2">
              <button className="btn btn-ghost" onClick={() => copy(tempVisible.new!)}>
                Copiar
              </button>
              <button
                className="btn btn-ghost"
                onClick={() =>
                  setTempVisible((m) => {
                    const n = { ...m };
                    delete n.new;
                    return n;
                  })
                }
              >
                Ocultar
              </button>
            </div>
          </div>
        )}
      </div>

      {/* LISTADO */}
      <div className="card overflow-auto">
        <table className="min-w-full">
          <thead className="bg-gray-100">
            <tr>
              <th className="table-th">Email</th>
              <th className="table-th">Rol</th>
              <th className="table-th text-right">Descuento %</th>
              <th className="table-th text-center">Activo</th>
              <th className="table-th">Creado</th>
              <th className="table-th text-center">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {items.map((u) => {
              const ed = edits[u.id];
              const isSaved = lastSavedId === u.id;
              return (
                <tr
                  key={u.id}
                  className={`border-b ${isSaved ? "bg-green-50" : ed?.dirty ? "bg-blue-50/50" : ""}`}
                >
                  <td className="table-td">
                    <input
                      className="input"
                      value={ed?.email ?? ""}
                      onChange={(e) => onEditChange(u.id, { email: e.target.value })}
                    />
                  </td>
                  <td className="table-td">
                    <select
                      className="input"
                      value={ed?.role ?? "user"}
                      onChange={(e) => onEditChange(u.id, { role: e.target.value as Role })}
                    >
                      <option value="user">Usuario</option>
                      <option value="admin">Administrador</option>
                    </select>
                  </td>
                  <td className="table-td text-right">
                    <input
                      className="input text-right"
                      value={ed?.descuentoStr ?? ""}
                      onChange={(e) => onEditChange(u.id, { descuentoStr: e.target.value })}
                      inputMode="decimal"
                      placeholder="0"
                    />
                  </td>
                  <td className="table-td text-center">
                    <input
                      type="checkbox"
                      checked={!!ed?.isActive}
                      onChange={(e) => onEditChange(u.id, { isActive: e.target.checked })}
                    />
                  </td>
                  <td className="table-td">{fmtDate(u.createdAt)}</td>
                  <td className="table-td text-center">
                    <div className="flex items-center justify-center gap-2">
                      <button className="btn btn-primary" onClick={() => onSave(u.id)}>
                        Guardar
                      </button>
                      {/* Reset manual: abre prompt para ingresar nueva */}
                      <button
                        className="btn btn-ghost"
                        onClick={() => {
                          const p = prompt("Nueva contraseña (mín. 6 caracteres). Dejar vacío para cancelar:");
                          if (p && p.length >= 6) onReset(u.id, "manual", p);
                        }}
                        title="Asignar contraseña específica"
                      >
                        Reset (manual)
                      </button>
                      {/* Reset auto: genera temporal y la muestra */}
                      <button
                        className="btn btn-ghost"
                        onClick={() => onReset(u.id, "auto")}
                        title="Generar contraseña temporal"
                      >
                        Reset (auto)
                      </button>
                    </div>

                    {/* Si hay temporal para este usuario, mostrarla */}
                    {tempVisible[u.id] && (
                      <div className="mt-2 p-2 rounded bg-yellow-50 border border-yellow-200 flex items-center justify-between">
                        <div>
                          <div className="text-sm">Temporal:</div>
                          <div className="font-mono text-sm">{tempVisible[u.id]}</div>
                        </div>
                        <div className="flex gap-2">
                          <button className="btn btn-ghost" onClick={() => copy(tempVisible[u.id])}>
                            Copiar
                          </button>
                          <button
                            className="btn btn-ghost"
                            onClick={() =>
                              setTempVisible((m) => {
                                const n = { ...m };
                                delete n[u.id];
                                return n;
                              })
                            }
                          >
                            Ocultar
                          </button>
                        </div>
                      </div>
                    )}
                  </td>
                </tr>
              );
            })}
            {items.length === 0 && !loading && (
              <tr>
                <td className="table-td text-center text-gray-500" colSpan={6}>
                  No hay usuarios.
                </td>
              </tr>
            )}
          </tbody>
        </table>

        {loading && <div className="text-sm text-gray-500 mt-2">Cargando…</div>}
      </div>
    </div>
  );
}
