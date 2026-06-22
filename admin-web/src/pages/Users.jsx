import React, { useState, useEffect } from 'react';
import apiClient from '../services/axios';
import DataTable from '../components/DataTable';

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const res = await apiClient.get('/admin/users');
      if (res.data.success) {
        setUsers(res.data.data);
      }
    } catch (err) {
      console.error("Gagal mengambil data user", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleStatusChange = async (userId, newStatus) => {
    try {
      const res = await apiClient.patch(`/admin/users/${userId}/status`, { accountStatus: newStatus });
      if (res.data.success) {
        // Update local state
        setUsers(users.map(u => u.id === userId ? { ...u, accountStatus: newStatus } : u));
      }
    } catch (err) {
      console.error("Gagal mengubah status", err);
      alert("Gagal mengubah status pengguna.");
    }
  };

  const columns = [
    { header: 'Username', accessor: 'username' },
    { header: 'Email', accessor: 'email' },
    { header: 'Total Jurnal', cell: (row) => row._count?.journals || 0 },
    { 
      header: 'Status Akun', 
      cell: (row) => {
        const colors = {
          ACTIVE: 'bg-green-100 text-green-800',
          SUSPEND: 'bg-yellow-100 text-yellow-800',
          BANNED: 'bg-red-100 text-red-800'
        };
        return (
          <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${colors[row.accountStatus]}`}>
            {row.accountStatus}
          </span>
        );
      }
    },
    {
      header: 'Aksi',
      cell: (row) => (
        <select 
          value={row.accountStatus}
          onChange={(e) => handleStatusChange(row.id, e.target.value)}
          className="text-sm border border-gray-300 rounded-md px-2 py-1 focus:ring-primary focus:border-primary outline-none"
        >
          <option value="ACTIVE">ACTIVE</option>
          <option value="SUSPEND">SUSPEND</option>
          <option value="BANNED">BANNED</option>
        </select>
      )
    }
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Kelola Akun (Mitigasi Kecurangan)</h1>
          <p className="text-gray-500 mt-1">Pantau dan kelola status akun pengguna seluler nusa.io.</p>
        </div>
      </div>

      <DataTable 
        columns={columns} 
        data={users} 
        loading={loading}
      />
    </div>
  );
};

export default Users;
