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
