import { create } from 'zustand';

// Mengambil status dari localStorage (agar persisten saat reload)
const getInitialState = () => {
  try {
    const userStr = localStorage.getItem('adminUser');
    if (userStr) {
      return { user: JSON.parse(userStr), isAuthenticated: true };
    }
  } catch (error) {
    console.error("Error parsing adminUser from localStorage", error);
  }
  return { user: null, isAuthenticated: false };
};

const useAuthStore = create((set) => ({
  ...getInitialState(),
  
  login: (userData) => {
    localStorage.setItem('adminUser', JSON.stringify(userData));
    set({ user: userData, isAuthenticated: true });
  },
  
  logout: () => {
    localStorage.removeItem('adminUser');
    set({ user: null, isAuthenticated: false });
  }
}));

export default useAuthStore;
