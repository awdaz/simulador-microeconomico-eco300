import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const links = [
  { to: '/dashboard', label: 'Resumen', icon: '▦' },
  { to: '/simulations', label: 'Simulaciones', icon: '◈' },
  { to: '/products', label: 'Productos', icon: '▤' },
];

export default function Layout() {
  const { user, logout, isAdmin } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login', { replace: true });
  };

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">ECO</span>
          <div>
            <strong>Simulador</strong>
            <small>Microeconómico · ECO300</small>
          </div>
        </div>

        <nav className="nav">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
            >
              <span className="nav-icon">{link.icon}</span>
              {link.label}
            </NavLink>
          ))}
          {isAdmin && (
            <NavLink
              to="/admin"
              className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
            >
              <span className="nav-icon">⚙</span>
              Administración
            </NavLink>
          )}
        </nav>

        <div className="sidebar-footer">
          <div className="user-block">
            <div className="avatar">{user?.name?.charAt(0).toUpperCase() || 'U'}</div>
            <div className="user-meta">
              <strong>{user?.name}</strong>
              <small>{user?.email}</small>
            </div>
          </div>
          <button className="btn btn-ghost btn-block" onClick={handleLogout}>
            Cerrar sesión
          </button>
        </div>
      </aside>

      <main className="main-content">
        <Outlet />
      </main>
    </div>
  );
}
