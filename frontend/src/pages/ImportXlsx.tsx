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
