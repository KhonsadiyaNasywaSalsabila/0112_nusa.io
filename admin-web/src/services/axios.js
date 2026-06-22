import axios from 'axios';

// Konfigurasi dasar Axios
const apiClient = axios.create({
  baseURL: 'http://localhost:3000/api/v1',
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor untuk menangani error respons
apiClient.interceptors.response.use((response) => {
  return response;
}, (error) => {
  if (error.response && (error.response.status === 401 || error.response.status === 403)) {
    // Jika token kedaluwarsa atau akses ditolak, hapus token dan kembali ke halaman login
    // Tapi cegah loop jika sedang berada di /login
    if (window.location.pathname !== '/login') {
      localStorage.removeItem('adminUser');
      window.location.href = '/login';
    }
  }
  return Promise.reject(error);
});

export default apiClient;
