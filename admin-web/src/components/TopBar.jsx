import React from 'react';
import { LogOut, Bell } from 'lucide-react';
import useAuthStore from '../store/useAuthStore';
import { useLocation, useNavigate } from 'react-router-dom';
import apiClient from '../services/axios';

const TopBar = () => {
  const { user, logout } = useAuthStore();
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      // Panggil backend untuk menghapus cookie httpOnly
      await apiClient.post('/admin/logout');
    } catch (error) {
      console.error('Logout API failed', error);
    } finally {
      // Hapus state lokal dan arahkan ke login
      logout();
      navigate('/login');
    }
  };

  // Simple Breadcrumb mapping
  const breadcrumb = {
    '/': 'Dashboard',
    '/journals': 'Moderasi Jurnal',
    '/locations': 'Master Lokasi',
    '/users': 'Kelola Akun',
  }[location.pathname] || 'Dashboard';

  return (
    <header className="bg-white border-b border-gray-200 h-16 flex items-center justify-between px-6 z-10 shadow-sm">
      <div className="flex items-center">
        <h2 className="text-xl font-semibold text-gray-800">{breadcrumb}</h2>
      </div>
      
      <div className="flex items-center space-x-4">
        <button className="p-2 text-gray-400 hover:text-gray-600 rounded-full hover:bg-gray-100 transition-colors">
          <Bell className="w-5 h-5" />
        </button>
        
        <div className="h-8 w-px bg-gray-200 mx-2"></div>
        
        <div className="flex items-center space-x-3">
          <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center text-white font-bold shadow-sm">
            {user?.username?.charAt(0).toUpperCase()}
          </div>
          <div className="flex flex-col">
            <span className="text-sm font-medium text-gray-700 leading-none">{user?.username}</span>
            <span className="text-xs text-gray-500 mt-1">{user?.role}</span>
          </div>
        </div>

        <button 
          onClick={handleLogout}
          className="ml-4 p-2 text-red-500 hover:bg-red-50 rounded-md transition-colors flex items-center space-x-1"
          title="Keluar"
        >
          <LogOut className="w-4 h-4" />
        </button>
      </div>
    </header>
  );
};

export default TopBar;
