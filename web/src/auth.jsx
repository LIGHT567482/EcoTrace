import { createContext, useContext, useEffect, useState } from "react";
import { api, cacheUser, getCachedUser, getAccess, logout as clearAuth } from "./api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(getCachedUser());
  const [loading, setLoading] = useState(!!getAccess());

  useEffect(() => {
    if (!getAccess()) return;
    api("/auth/me/")
      .then((me) => {
        setUser(me);
        cacheUser(me);
      })
      .catch(() => {
        setUser(null);
      })
      .finally(() => setLoading(false));
  }, []);

  const loginAs = (u) => {
    setUser(u);
    cacheUser(u);
  };

  const logout = () => {
    clearAuth();
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, setUser: loginAs, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
