import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import useAuthStore from './store/useAuthStore';

// Pages
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Journals from './pages/Journals';
import Locations from './pages/Locations';
import Users from './pages/Users';

import ProtectedRoute from './components/ProtectedRoute';

const App = () => {
  const { isAuthenticated } = useAuthStore();

  return (
    <Routes>
      {/* Public Route */}
      <Route 
        path="/login" 
        element={isAuthenticated ? <Navigate to="/" replace /> : <Login />} 
      />

      {/* Protected Routes inside Layout */}
      <Route element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route path="/" element={<Dashboard />} />
        <Route path="journals" element={<Journals />} />
        
        {/* Hanya SUPER_ADMIN */}
        <Route 
          path="locations" 
          element={
            <ProtectedRoute allowedRoles={['SUPER_ADMIN']}>
              <Locations />
            </ProtectedRoute>
          } 
        />
        
        {/* Kelola Akun (Users) - SUPER_ADMIN & MODERATOR */}
        <Route 
          path="users" 
          element={
            <ProtectedRoute allowedRoles={['SUPER_ADMIN', 'MODERATOR']}>
              <Users />
            </ProtectedRoute>
          } 
        />
      </Route>

      {/* Fallback Route */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

export default App;
