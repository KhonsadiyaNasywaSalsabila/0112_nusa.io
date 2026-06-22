import React, { useState, useEffect } from 'react';
import apiClient from '../services/axios';
import DataTable from '../components/DataTable';
import Modal from '../components/Modal';

const Journals = () => {
  const [journals, setJournals] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedJournal, setSelectedJournal] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const fetchJournals = async () => {
    try {
      setLoading(true);
      const res = await apiClient.get('/admin/journals/reported');
      if (res.data.success) {
        setJournals(res.data.data);
      }
    } catch (err) {
      console.error("Gagal mengambil data jurnal", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchJournals();
  }, []);

  const handleToggleBlock = async (journal) => {
    const newStatus = journal.status === 'BLOCKED' ? 'PUBLISHED' : 'BLOCKED';
    if (!window.confirm(`Yakin ingin mengubah status jurnal menjadi ${newStatus}?`)) return;
    
    try {
      const res = await apiClient.patch(`/admin/journals/${journal.id}/status`, { status: newStatus });
      if (res.data.success) {
        setJournals(journals.map(j => j.id === journal.id ? { ...j, status: newStatus } : j));
        setIsModalOpen(false);
      }
    } catch (err) {
      console.error("Gagal mengubah status jurnal", err);
      alert("Gagal mengubah status jurnal.");
    }
  };

  const openReviewModal = (journal) => {
    setSelectedJournal(journal);
    setIsModalOpen(true);
  };

  const columns = [
    { header: 'Penulis', cell: (row) => row.user?.username || 'Unknown' },
    { header: 'Lokasi', cell: (row) => row.location?.name || 'Unknown' },
    { header: 'Jumlah Laporan', accessor: 'reportCount' },
    { 
      header: 'Status', 
      cell: (row) => {
        const isBlocked = row.status === 'BLOCKED';
        return (
          <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${isBlocked ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'}`}>
            {row.status}
          </span>
        );
      }
    },
    {
      header: 'Aksi',
      cell: (row) => (
        <button 
          onClick={() => openReviewModal(row)}
          className="text-sm bg-blue-50 text-blue-600 hover:bg-blue-100 px-3 py-1.5 rounded-md transition-colors"
        >
          Tinjau
        </button>
      )
    }
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Moderasi Konten Publik</h1>
          <p className="text-gray-500 mt-1">Tinjau dan tindaklanjuti jurnal-jurnal yang dilaporkan oleh komunitas.</p>
        </div>
      </div>

      <DataTable 
        columns={columns} 
        data={journals} 
        loading={loading}
      />

      {/* Review Modal */}
      <Modal 
        isOpen={isModalOpen} 
        onClose={() => setIsModalOpen(false)}
        title="Tinjau Laporan Jurnal"
      >
        {selectedJournal && (
          <div className="space-y-4">
            {selectedJournal.media && selectedJournal.media.length > 0 && (
              <img 
                src={`http://localhost:3000${selectedJournal.media[0].mediaUrl}`} 
                alt="Lampiran Jurnal" 
                className="w-full h-48 object-cover rounded-lg"
                onError={(e) => { e.target.src = 'https://via.placeholder.com/400x200?text=No+Image'; }}
              />
            )}
            <div>
              <h4 className="text-sm font-semibold text-gray-500 uppercase">Konten Jurnal</h4>
              <p className="mt-1 text-gray-800 whitespace-pre-wrap">{selectedJournal.content}</p>
            </div>
            <div className="grid grid-cols-2 gap-4 bg-gray-50 p-3 rounded-lg border border-gray-100">
              <div>
                <p className="text-xs text-gray-500">Penulis</p>
                <p className="text-sm font-medium">{selectedJournal.user?.username}</p>
              </div>
              <div>
                <p className="text-xs text-gray-500">Total Dilaporkan</p>
                <p className="text-sm font-medium text-red-600">{selectedJournal.reportCount} kali</p>
              </div>
            </div>
            
            <div className="pt-4 flex space-x-3 border-t border-gray-100">
              <button 
                onClick={() => setIsModalOpen(false)}
                className="flex-1 py-2 px-4 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium transition-colors"
              >
                Tutup
              </button>
              {selectedJournal.status !== 'BLOCKED' ? (
                <button 
                  onClick={() => handleToggleBlock(selectedJournal)}
                  className="flex-1 py-2 px-4 bg-red-600 text-white rounded-lg hover:bg-red-700 font-medium transition-colors"
                >
                  Blokir (Soft Delete)
                </button>
              ) : (
                <button 
                  onClick={() => handleToggleBlock(selectedJournal)}
                  className="flex-1 py-2 px-4 bg-green-600 text-white rounded-lg hover:bg-green-700 font-medium transition-colors"
                >
                  Pulihkan (Published)
                </button>
              )}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

export default Journals;
