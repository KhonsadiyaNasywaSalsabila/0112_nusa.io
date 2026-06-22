import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, MapPin, ShieldAlert, Users } from 'lucide-react';
import useAuthStore from '../store/useAuthStore';

const Sidebar = () => {
  const { user } = useAuthStore();
  
  // RBAC: Hanya SUPER_ADMIN yang bisa akses Master Lokasi dan Kelola Admin
  const isSuperAdmin = user?.role === 'SUPER_ADMIN';

  const navItems = [
    { name: 'Dashboard', path: '/', icon: <LayoutDashboard className="w-5 h-5" /> },
    { name: 'Moderasi Jurnal', path: '/journals', icon: <ShieldAlert className="w-5 h-5" /> },
    { name: 'Kelola Akun', path: '/users', icon: <Users className="w-5 h-5" /> },
    ...(isSuperAdmin ? [
      { name: 'Master Lokasi', path: '/locations', icon: <MapPin className="w-5 h-5" /> },
    ] : [])
  ];

  return (
    <aside className="w-64 bg-dark text-white shadow-xl flex flex-col transition-all duration-300">
      <div className="h-16 flex items-center px-6 border-b border-gray-700/50 bg-dark-card">
        <div className="flex items-center space-x-2">
          <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center font-bold text-white shadow-lg shadow-primary/30">
            N
          </div>
          <span className="text-xl font-bold tracking-tight text-white">nusa.io <span className="text-xs font-normal text-gray-400">admin</span></span>
        </div>
      </div>
      
      <div className="flex-1 overflow-y-auto py-6">
        <nav className="space-y-1 px-3">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `flex items-center px-3 py-2.5 rounded-lg transition-all duration-200 group ${
                  isActive 
                    ? 'bg-primary/10 text-primary font-medium' 
                    : 'text-gray-400 hover:bg-gray-800 hover:text-white'
                }`
              }
            >
              <div className="mr-3">{item.icon}</div>
              {item.name}
            </NavLink>
          ))}
        </nav>
      </div>
      
      <div className="p-4 border-t border-gray-800 text-xs text-gray-500 text-center">
        &copy; {new Date().getFullYear()} nusa.io
      </div>
    </aside>
  );
};

export default Sidebar;
