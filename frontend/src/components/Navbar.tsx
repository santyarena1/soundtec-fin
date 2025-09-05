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
