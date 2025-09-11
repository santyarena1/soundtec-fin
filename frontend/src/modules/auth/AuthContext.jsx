import React, { createContext, useContext, useEffect, useMemo, useState } from "react";
import { api } from "../../services/api.js";

// Authentication context to manage login state and current user. Exposes signIn and signOut methods.
const AuthContext = createContext(undefined);

export function AuthProvider({ children }) {
  // Persist token and user in localStorage so state survives page reloads
  const [token, setToken] = useState(() => localStorage.getItem("token") || "");
  const [user, setUser] = useState(() => {
    const raw = localStorage.getItem("user");
    return raw ? JSON.parse(raw) : null;
  });
  const [loading, setLoading] = useState(false);

  // Whenever the token changes, update the api instance header
  useEffect(() => {
    api.setToken(token);
  }, [token]);

  // Sign in against the backend and store credentials
  const signIn = async (email, password) => {
    setLoading(true);
    try {
      const res = await api.post("/auth/login", { email, password });
      const nextToken = res.token || res.data?.token;
      const nextUser = res.user || res.data?.user || { email, role: "ADMIN" };
      if (!nextToken) throw new Error("No se recibió token");
      setToken(nextToken);
      setUser(nextUser);
      localStorage.setItem("token", nextToken);
      localStorage.setItem("user", JSON.stringify(nextUser));
      return { ok: true };
    } catch (e) {
      return { ok: false, error: e.message };
    } finally {
      setLoading(false);
    }
  };

  // Destroy session and clear storage
  const signOut = () => {
    setToken("");
    setUser(null);
    localStorage.removeItem("token");
    localStorage.removeItem("user");
  };

  const value = useMemo(
    () => ({ token, user, loading, signIn, signOut }),
    [token, user, loading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// Hook to access the auth context conveniently
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth debe usarse dentro de AuthProvider");
  return ctx;
}

// TypeScript interfaces and type annotations removed for JavaScript compatibility.