import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import client, { extractMessage } from '../api/client';

const AuthContext = createContext(null);

const readStoredUser = () => {
  try {
    return JSON.parse(localStorage.getItem('eco300_user') || 'null');
  } catch {
    return null;
  }
};

export function AuthProvider({ children }) {
  const [user, setUser] = useState(readStoredUser);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('eco300_token');
    if (!token) {
      setLoading(false);
      return;
    }
    client
      .get('/me')
      .then(({ data }) => {
        setUser(data);
        localStorage.setItem('eco300_user', JSON.stringify(data));
      })
      .catch(() => {
        localStorage.removeItem('eco300_token');
        localStorage.removeItem('eco300_user');
        setUser(null);
      })
      .finally(() => setLoading(false));
  }, []);

  const persist = (data) => {
    localStorage.setItem('eco300_token', data.token);
    localStorage.setItem('eco300_user', JSON.stringify(data.user));
    setUser(data.user);
  };

  const login = useCallback(async (email, password) => {
    const { data } = await client.post('/login', { email, password });
    persist(data);
    return data;
  }, []);

  const register = useCallback(async (payload) => {
    const { data } = await client.post('/register', payload);
    persist(data);
    return data;
  }, []);

  const logout = useCallback(async () => {
    try {
      await client.post('/logout');
    } catch {
      // El token ya no sirve; limpiamos igual.
    }
    localStorage.removeItem('eco300_token');
    localStorage.removeItem('eco300_user');
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({ user, loading, login, register, logout, isAdmin: user?.role === 'admin' }),
    [user, loading, login, register, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth debe usarse dentro de AuthProvider');
  return context;
}

export { extractMessage };
