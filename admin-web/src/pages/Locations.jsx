import React, { useState, useEffect, useCallback } from 'react';
import apiClient from '../services/axios';
import DataTable from '../components/DataTable';
import Modal from '../components/Modal';
import { GoogleMap, useJsApiLoader, Marker, Circle } from '@react-google-maps/api';

const mapContainerStyle = { width: '100%', height: '300px' };
const defaultCenter = { lat: -0.789275, lng: 113.921327 }; // Default ke tengah Indonesia

const Locations = () => {
  const [locations, setLocations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [modalMode, setModalMode] = useState('create'); // 'create', 'edit', 'view'
  const [selectedLocationId, setSelectedLocationId] = useState(null);

  const { isLoaded } = useJsApiLoader({
    id: 'google-map-script',
    googleMapsApiKey: import.meta.env.VITE_GOOGLE_MAPS_API_KEY
  });

  const [mapCenter, setMapCenter] = useState(defaultCenter);

  const [formData, setFormData] = useState({
    name: '',
    latitude: '',
    longitude: '',
    geofenceRadius: 100,
    description: '',
    coverPhoto: null,
    existingPhotoUrl: null
  });

  const fetchLocations = async () => {
    try {
      setLoading(true);
      const res = await apiClient.get('/admin/locations');
      if (res.data.success) {
        setLocations(res.data.data);
      }
    } catch (err) {
      console.error("Gagal mengambil data lokasi", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLocations();
  }, []);

  const openCreateModal = () => {
    setModalMode('create');
    setSelectedLocationId(null);
    setFormData({ name: '', latitude: '', longitude: '', geofenceRadius: 100, description: '', coverPhoto: null, existingPhotoUrl: null });
    setMapCenter(defaultCenter);
    setIsModalOpen(true);
  };

  const openEditModal = (loc) => {
    setModalMode('edit');
    setSelectedLocationId(loc.id);
    setFormData({ 
      name: loc.name, 
      latitude: loc.latitude.toString(), 
      longitude: loc.longitude.toString(), 
      geofenceRadius: loc.geofenceRadius, 
      description: loc.description || '', 
      coverPhoto: null,
      existingPhotoUrl: loc.coverPhotoUrl
    });
    setMapCenter({ lat: parseFloat(loc.latitude), lng: parseFloat(loc.longitude) });
    setIsModalOpen(true);
  };

  const openViewModal = (loc) => {
    setModalMode('view');
    setSelectedLocationId(loc.id);
    setFormData({ 
      name: loc.name, 
      latitude: loc.latitude.toString(), 
      longitude: loc.longitude.toString(), 
      geofenceRadius: loc.geofenceRadius, 
      description: loc.description || '', 
      coverPhoto: null,
      existingPhotoUrl: loc.coverPhotoUrl
    });
    setMapCenter({ lat: parseFloat(loc.latitude), lng: parseFloat(loc.longitude) });
    setIsModalOpen(true);
  };

  const handleToggleActive = async (loc) => {
    const action = loc.isActive ? 'mengarsipkan' : 'memulihkan';
    if (window.confirm(`Apakah Anda yakin ingin ${action} lokasi ini?`)) {
      try {
        const formData = new FormData();
        formData.append('isActive', !loc.isActive);

        const res = await apiClient.patch(`/admin/locations/${loc.id}`, formData, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });

        if (res.data.success) {
          setLocations(locations.map(l => l.id === loc.id ? { ...l, isActive: !loc.isActive } : l));
        }
      } catch (err) {
        console.error("Gagal mengupdate status lokasi", err);
        alert(`Gagal ${action} lokasi.`);
      }
    }
  };

  const handleInputChange = (e) => {
    if (modalMode === 'view') return;
    const { name, value, files } = e.target;
    if (name === 'coverPhoto') {
      setFormData({ ...formData, coverPhoto: files[0] });
    } else {
      setFormData({ ...formData, [name]: value });
      if ((name === 'latitude' || name === 'longitude') && value) {
        const num = parseFloat(value);
        if (!isNaN(num)) {
          setMapCenter(prev => ({
            ...prev,
            [name === 'latitude' ? 'lat' : 'lng']: num
          }));
        }
      }
    }
  };

  const handleMapClick = useCallback((event) => {
    if (modalMode === 'view') return;
    const lat = event.latLng.lat();
    const lng = event.latLng.lng();
    setFormData(prev => ({
      ...prev,
      latitude: lat.toFixed(6),
      longitude: lng.toFixed(6)
    }));
    setMapCenter({ lat, lng });
  }, [modalMode]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (modalMode === 'view') {
      setIsModalOpen(false);
      return;
    }

    setIsSubmitting(true);
    const data = new FormData();
    data.append('name', formData.name);
    data.append('latitude', formData.latitude);
    data.append('longitude', formData.longitude);
    data.append('geofenceRadius', formData.geofenceRadius);
    data.append('description', formData.description);
    if (formData.coverPhoto) {
      data.append('coverPhoto', formData.coverPhoto);
    }

    try {
      if (modalMode === 'create') {
        const res = await apiClient.post('/admin/locations', data, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });
        if (res.data.success) {
          setLocations([res.data.data, ...locations]);
          setIsModalOpen(false);
        }
      } else if (modalMode === 'edit') {
        const res = await apiClient.patch(`/admin/locations/${selectedLocationId}`, data, {
          headers: { 'Content-Type': 'multipart/form-data' }
        });
        if (res.data.success) {
          setLocations(locations.map(loc => loc.id === selectedLocationId ? res.data.data : loc));
          setIsModalOpen(false);
        }
      }
    } catch (err) {
      console.error("Gagal menyimpan lokasi", err);
      alert(err.response?.data?.message || "Gagal menyimpan lokasi.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const columns = [
    { header: 'Nama Tempat', accessor: 'name' },
    { 
      header: 'Status', 
      cell: (row) => (
        <span className={`px-2 py-1 rounded text-xs font-medium ${row.isActive ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
          {row.isActive ? 'Aktif' : 'Arsip'}
        </span>
      )
    },
    { 
      header: 'Koordinat', 
      cell: (row) => <span className="text-gray-500 text-xs font-mono">{row.latitude}, {row.longitude}</span> 
    },
    { header: 'Radius (m)', accessor: 'geofenceRadius' },
    {
      header: 'Aksi',
      cell: (row) => (
        <div className="flex gap-3 items-center">
          <button onClick={() => openViewModal(row)} className="text-sm text-blue-500 hover:text-blue-700">Detail</button>
          <button onClick={() => openEditModal(row)} className="text-sm text-yellow-500 hover:text-yellow-700">Edit</button>
          <button onClick={() => handleToggleActive(row)} className={`text-sm ${row.isActive ? 'text-red-500 hover:text-red-700' : 'text-green-500 hover:text-green-700'}`}>
            {row.isActive ? 'Arsipkan' : 'Pulihkan'}
          </button>
        </div>
      )
    }
  ];

  const parsedLat = parseFloat(formData.latitude);
  const parsedLng = parseFloat(formData.longitude);
  const parsedRadius = parseFloat(formData.geofenceRadius);
  const hasValidCoords = !isNaN(parsedLat) && !isNaN(parsedLng);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Master Lokasi</h1>
          <p className="text-gray-500 mt-1">Kelola daftar area Geofence wisata yang diakui nusa.io.</p>
        </div>
        <button 
          onClick={openCreateModal}
          className="bg-primary hover:bg-primary-dark text-white px-4 py-2 rounded-lg font-medium transition-colors shadow-sm"
        >
          + Tambah Lokasi
        </button>
      </div>

      <DataTable 
        columns={columns} 
        data={locations} 
        loading={loading}
      />

      <Modal 
        isOpen={isModalOpen} 
        onClose={() => setIsModalOpen(false)}
        title={modalMode === 'create' ? "Tambah Lokasi Baru" : modalMode === 'edit' ? "Edit Lokasi" : "Detail Lokasi"}
      >
        <form onSubmit={handleSubmit} className="space-y-4 max-h-[80vh] overflow-y-auto pr-2">
          
          {isLoaded ? (
            <div className={`rounded-lg overflow-hidden border border-gray-300 relative ${modalMode === 'view' ? 'opacity-80' : ''}`}>
              <GoogleMap
                mapContainerStyle={mapContainerStyle}
                center={mapCenter}
                zoom={10}
                onClick={handleMapClick}
                options={{ streetViewControl: false, mapTypeControl: false, disableDefaultUI: modalMode === 'view' }}
              >
                {hasValidCoords && (
                  <>
                    <Marker position={{ lat: parsedLat, lng: parsedLng }} />
                    {!isNaN(parsedRadius) && parsedRadius > 0 && (
                      <Circle
                        center={{ lat: parsedLat, lng: parsedLng }}
                        radius={parsedRadius}
                        options={{
                          fillColor: '#10b981',
                          fillOpacity: 0.3,
                          strokeColor: '#059669',
                          strokeOpacity: 0.8,
                          strokeWeight: 2,
                        }}
                      />
                    )}
                  </>
                )}
              </GoogleMap>
              {modalMode !== 'view' && (
                <div className="absolute top-2 right-2 bg-white px-2 py-1 text-xs rounded shadow-md z-10 opacity-80 pointer-events-none">
                  Klik peta untuk set koordinat
                </div>
              )}
            </div>
          ) : (
            <div className="w-full h-[300px] bg-gray-100 animate-pulse rounded-lg flex items-center justify-center text-gray-400 text-sm border border-gray-300">
              Memuat Peta...
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Nama Tempat Wisata</label>
            <input 
              type="text" name="name" required disabled={modalMode === 'view'}
              value={formData.name} onChange={handleInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-primary focus:border-primary outline-none disabled:bg-gray-100 disabled:text-gray-500"
            />
          </div>
          
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Latitude</label>
              <input 
                type="number" step="any" name="latitude" required disabled={modalMode === 'view'}
                value={formData.latitude} onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-primary focus:border-primary outline-none font-mono text-sm disabled:bg-gray-100 disabled:text-gray-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Longitude</label>
              <input 
                type="number" step="any" name="longitude" required disabled={modalMode === 'view'}
                value={formData.longitude} onChange={handleInputChange}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-primary focus:border-primary outline-none font-mono text-sm disabled:bg-gray-100 disabled:text-gray-500"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Radius Geofence (meter)</label>
            <input 
              type="number" name="geofenceRadius" required min="10" disabled={modalMode === 'view'}
              value={formData.geofenceRadius} onChange={handleInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-primary focus:border-primary outline-none disabled:bg-gray-100 disabled:text-gray-500"
            />
            {modalMode !== 'view' && (
              <p className="text-xs text-gray-500 mt-1">Jarak toleransi maksimal jurnal bisa dipublikasikan.</p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Deskripsi Singkat</label>
            <textarea 
              name="description" rows="2" disabled={modalMode === 'view'}
              value={formData.description} onChange={handleInputChange}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-primary focus:border-primary outline-none disabled:bg-gray-100 disabled:text-gray-500"
            ></textarea>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Foto Sampul</label>
            {formData.existingPhotoUrl && (
              <div className="mb-2 rounded-lg overflow-hidden border border-gray-200">
                <img src={`http://localhost:3000${formData.existingPhotoUrl}`} alt="Cover" className="w-full h-40 object-cover" />
              </div>
            )}
            {modalMode !== 'view' && (
              <input 
                type="file" name="coverPhoto" accept="image/*"
                onChange={handleInputChange}
                className="w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-primary/10 file:text-primary hover:file:bg-primary/20"
              />
            )}
            {modalMode === 'view' && !formData.existingPhotoUrl && (
              <p className="text-sm text-gray-500 italic">Tidak ada foto sampul</p>
            )}
          </div>

          <div className="pt-4 border-t border-gray-100 flex justify-end gap-3">
            <button 
              type="button" 
              onClick={() => setIsModalOpen(false)}
              className="px-6 py-2 rounded-lg font-medium bg-gray-100 hover:bg-gray-200 text-gray-700 transition-colors"
            >
              {modalMode === 'view' ? 'Tutup' : 'Batal'}
            </button>
            {modalMode !== 'view' && (
              <button 
                type="submit" disabled={isSubmitting}
                className="bg-primary text-white px-6 py-2 rounded-lg font-medium hover:bg-primary-dark transition-colors disabled:opacity-70"
              >
                {isSubmitting ? 'Menyimpan...' : (modalMode === 'create' ? 'Simpan' : 'Update')}
              </button>
            )}
          </div>
        </form>
      </Modal>
    </div>
  );
};

export default Locations;
