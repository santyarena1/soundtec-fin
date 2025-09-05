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
