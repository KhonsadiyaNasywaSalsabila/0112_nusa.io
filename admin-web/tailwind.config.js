/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#10b981', // emerald-500
          dark: '#059669',    // emerald-600
        },
        dark: {
          DEFAULT: '#111827', // gray-900
          card: '#1f2937',    // gray-800
        }
      }
    },
  },
  plugins: [],
}
