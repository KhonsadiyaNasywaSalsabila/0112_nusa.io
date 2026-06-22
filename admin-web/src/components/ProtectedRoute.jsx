import React from 'react';
import { Navigate } from 'react-router-dom';
import useAuthStore from '../store/useAuthStore';

const ProtectedRoute = ({ children, allowedRoles }) => {
  const { isAuthenticated, user } = useAuthStore();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // Jika allowedRoles disediakan dan role user tidak termasuk di dalamnya
  if (allowedRoles && (!user || !allowedRoles.includes(user.role))) {
    // Tendang balik ke Dashboard utama jika role tidak sesuai (misal: Moderator buka /locations)
    return <Navigate to="/" replace />;
  }

  return children;
};

export default ProtectedRoute;
