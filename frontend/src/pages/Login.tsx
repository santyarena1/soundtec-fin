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
