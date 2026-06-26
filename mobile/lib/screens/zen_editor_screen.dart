import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/database_helper.dart';
import '../repositories/journal_repository.dart';
import '../utils/constants.dart';

class ZenEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? draftData;

  const ZenEditorScreen({Key? key, this.draftData}) : super(key: key);

  @override
  State<ZenEditorScreen> createState() => _ZenEditorScreenState();
}

class _ZenEditorScreenState extends State<ZenEditorScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<String> _themes = AppConstants.themeTags;
  String? _selectedTheme;
  final List<File> _selectedImages = [];
  final FocusNode _contentFocusNode = FocusNode();
  final List<String> _prompts = [
    "Apa hal paling menarik yang kamu temui di sini?",
    "Bagaimana suasana tempat ini menurutmu?",
    "Ada memori apa yang ingin kamu simpan hari ini?",
    "Ceritakan satu detail kecil yang membuatmu tersenyum.",
    "Siapa yang sedang bersamamu, dan bagaimana perasaanmu?"
  ];
  late String _randomPrompt;
  
  bool _isLoading = true;
  bool _isOnline = true;
  Map<String, dynamic>? _matchedLocation;
  Position? _currentPosition;
  
  Timer? _debounceTimer;
  int? _localDraftId;
  final List<String> _existingNetworkImages = [];

  @override
  void initState() {
    super.initState();
    _randomPrompt = _prompts[math.Random().nextInt(_prompts.length)];
    _contentFocusNode.addListener(() {
      setState(() {}); // Pemicu render ulang untuk Fading UI
    });

    if (widget.draftData != null) {
      _contentController.text = widget.draftData!['content'] ?? '';
      _selectedTheme = widget.draftData!['themeTag'];
      if (widget.draftData!['isLocal'] == 1 || widget.draftData!['isLocal'] == true) {
        _localDraftId = int.tryParse(widget.draftData!['id'].toString());
      }
      
      if (widget.draftData!['localMediaPaths'] != null && widget.draftData!['localMediaPaths'].toString().isNotEmpty) {
        List<String> paths = widget.draftData!['localMediaPaths'].toString().split(',');
        for (String path in paths) {
          if (File(path).existsSync()) {
            _selectedImages.add(File(path));
          }
        }
      }

      if (widget.draftData!['mediaUrls'] != null && widget.draftData!['mediaUrls'] is List) {
        _existingNetworkImages.addAll(List<String>.from(widget.draftData!['mediaUrls']));
      }
    }
    
    _contentController.addListener(_onTextChanged);
    _checkStatusAndLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      _autoSaveDraft();
    });
  }

  Future<void> _autoSaveDraft() async {
    if (_contentController.text.trim().isEmpty || _matchedLocation == null || _currentPosition == null || _selectedTheme == null) {
      return; // Jangan simpan jika data belum lengkap
    }

    final draft = {
      'locationId': _matchedLocation!['id'],
      'rootJournalId': widget.draftData?['rootJournalId'],
      'content': _contentController.text.trim(),
      'themeTag': _selectedTheme,
      'latitudeCaptured': widget.draftData?['latitudeCaptured'] ?? _currentPosition!.latitude,
      'longitudeCaptured': widget.draftData?['longitudeCaptured'] ?? _currentPosition!.longitude,
      'isMocked': _currentPosition!.isMocked ? 1 : 0,
      'imagePaths': _selectedImages.map((f) => f.path).join(','),
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      if (_localDraftId != null) {
        await DatabaseHelper.instance.updateDraft(_localDraftId!, draft);
      } else {
        _localDraftId = await DatabaseHelper.instance.insertDraft(draft);
      }
      debugPrint("Auto-saved draft: $_localDraftId");
    } catch (e) {
      debugPrint("Failed to auto-save: $e");
    }
  }

  Future<void> _checkStatusAndLocation() async {
    // 1. Cek Koneksi (Online / Offline)
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    bool isOnline = !connectivityResult.contains(ConnectivityResult.none);
    setState(() {
      _isOnline = isOnline;
    });

    if (widget.draftData == null || widget.draftData!['locationId'] == null) {
      _showErrorAndExit("Data lokasi tidak ditemukan. Editor ditutup.");
      return;
    }

    // Bypass GPS karena verifikasi sudah dilakukan di layar sebelumnya
    final locations = await DatabaseHelper.instance.getLocationsCache();
    Map<String, dynamic>? matchedLoc;
    for (var loc in locations) {
      if (loc['id'] == widget.draftData!['locationId']) {
        matchedLoc = loc;
        break;
      }
    }
    
    if (matchedLoc != null) {
      _currentPosition = Position(
        longitude: double.tryParse(widget.draftData!['longitudeCaptured'].toString()) ?? matchedLoc['longitude'],
        latitude: double.tryParse(widget.draftData!['latitudeCaptured'].toString()) ?? matchedLoc['latitude'],
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
        isMocked: widget.draftData!['isMocked'] == 1 || widget.draftData!['isMocked'] == true
      );
      setState(() {
        _matchedLocation = matchedLoc;
        _isLoading = false;
      });
    } else {
      _showErrorAndExit("Lokasi tujuan tidak ditemukan di dalam cache lokal.");
    }
  }

  void _showErrorAndExit(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Gagal Memuat"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              Navigator.pop(context); // Tutup screen Zen Editor
            },
            child: const Text("Kembali"),
          )
        ],
      )
    );
  }

  Future<void> _pickImages() async {
    // Kurangi keyboard agar tidak loncat
    _contentFocusNode.unfocus();
    
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();

    if (images != null) {
      int totalCount = _selectedImages.length + _existingNetworkImages.length;
      if (images.length + totalCount > 3) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maksimal 3 foto pendamping. Sisa foto diabaikan.'))
        );
      }

      setState(() {
        for (int i = 0; i < images.length; i++) {
          if (_selectedImages.length + _existingNetworkImages.length < 3) {
            _selectedImages.add(File(images[i].path));
          }
        }
      });
    }
  }

  Future<void> _submitJournal({bool publishNow = false}) async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konten tidak boleh kosong.')));
      return;
    }
    if (_selectedTheme == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih salah satu tema di bagian bawah.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isOnline) {
        // --- MODE ONLINE ---
        FormData formData = FormData.fromMap({
          'locationId': _matchedLocation!['id'],
          'content': _contentController.text,
          'themeTag': _selectedTheme,
          'latitudeCaptured': _currentPosition!.latitude,
          'longitudeCaptured': _currentPosition!.longitude,
          'isMocked': _currentPosition!.isMocked.toString(),
        });
        
        if (widget.draftData != null && widget.draftData!['rootJournalId'] != null) {
          formData.fields.add(MapEntry('rootJournalId', widget.draftData!['rootJournalId']));
        }

        for (var file in _selectedImages) {
          formData.files.add(MapEntry(
            'photos',
            await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
          ));
        }

        bool isLocal = widget.draftData != null ? (widget.draftData!['isLocal'] == 1 || widget.draftData!['isLocal'] == true) : false;

        if (widget.draftData != null && widget.draftData!['id'] != null && !isLocal) {
          // Jika edit Draf Server
          final updateRes = await context.read<JournalRepository>().updateJournal(
            widget.draftData!['id'],
            formData,
          );

          if (updateRes.statusCode == 200) {
            if (publishNow && widget.draftData?['status'] != 'PUBLISHED') {
              await context.read<JournalRepository>().publishJournal(widget.draftData!['id']);
              if (_localDraftId != null) {
                await DatabaseHelper.instance.deleteDraft(_localDraftId!);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jurnal diterbitkan & Stempel didapat!')));
                Navigator.pop(context, true);
              }
            } else {
              if (_localDraftId != null) {
                await DatabaseHelper.instance.deleteDraft(_localDraftId!);
              }
              if (mounted) {
                String msg = widget.draftData?['status'] == 'PUBLISHED' ? 'Jurnal berhasil diperbarui!' : 'Draf berhasil diperbarui!';
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                Navigator.pop(context, true);
              }
            }
          }
        } else {
          // Buat Baru (POST)
          final createRes = await context.read<JournalRepository>().createJournal(formData);

          if (createRes.statusCode == 201) {
            String newJournalId = createRes.data['data']['id'];

            if (publishNow) {
              await context.read<JournalRepository>().publishJournal(newJournalId);
              if (_localDraftId != null) {
                await DatabaseHelper.instance.deleteDraft(_localDraftId!);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jurnal diterbitkan & Stempel didapat!')));
                Navigator.pop(context, true);
              }
            } else {
              if (_localDraftId != null) {
                await DatabaseHelper.instance.deleteDraft(_localDraftId!);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan sebagai Draf di Server!')));
                Navigator.pop(context, true);
              }
            }
          }
        }
      } else {
        // --- MODE OFFLINE ---
        String imagePaths = _selectedImages.map((e) => e.path).join(',');

        Map<String, dynamic> draftDataToInsert = {
          'locationId': _matchedLocation!['id'],
          'content': _contentController.text,
          'themeTag': _selectedTheme,
          'latitudeCaptured': _currentPosition!.latitude,
          'longitudeCaptured': _currentPosition!.longitude,
          'isMocked': _currentPosition!.isMocked ? 1 : 0,
          'imagePaths': imagePaths,
          'createdAt': DateTime.now().toIso8601String(),
        };

        if (widget.draftData != null && widget.draftData!['rootJournalId'] != null) {
          draftDataToInsert['rootJournalId'] = widget.draftData!['rootJournalId'];
        }

        if (_localDraftId != null) {
          await DatabaseHelper.instance.updateDraft(_localDraftId!, draftDataToInsert);
        } else {
          await DatabaseHelper.instance.insertDraft(draftDataToInsert);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan di Saku (Offline Draft)')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error submit: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan saat memproses jurnal.')));
      }
    }
  }

  // --- Widget Builders for UI ---

  Widget _buildMediaGrid() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        clipBehavior: Clip.hardEdge,
        child: _selectedImages.isEmpty && _existingNetworkImages.isEmpty
            ? _buildEmptyMediaSlot()
            : _buildFilledMediaGrid(),
      ),
    );
  }

  Widget _buildEmptyMediaSlot() {
    return Container(
      height: 180,
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text("Tambahkan Foto Utama", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            Text("(Maks. 3, Opsional)", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilledMediaGrid() {
    List<Widget> imageWidgets = [];

    for (String url in _existingNetworkImages) {
      imageWidgets.add(
        Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url.startsWith('http') ? url : "http://10.0.2.2:3000${url.startsWith('/') ? '' : '/'}$url", 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image, color: Colors.white54),
              ),
            ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _existingNetworkImages.remove(url);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            )
          ]
        )
      );
    }

    for (int i = 0; i < _selectedImages.length; i++) {
      File file = _selectedImages[i];
      imageWidgets.add(
        Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImages.removeAt(i);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            )
          ]
        )
      );
    }

    if (imageWidgets.length == 1) {
      return SizedBox(height: 240, width: double.infinity, child: imageWidgets[0]);
    } else if (imageWidgets.length == 2) {
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(child: imageWidgets[0]),
            const SizedBox(width: 2),
            Expanded(child: imageWidgets[1]),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          SizedBox(height: 180, width: double.infinity, child: imageWidgets[0]),
          const SizedBox(height: 2),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Expanded(child: imageWidgets[1]),
                const SizedBox(width: 2),
                Expanded(child: imageWidgets.length > 2 ? imageWidgets[2] : Container(color: Colors.grey[200])),
              ],
            ),
          )
        ],
      );
    }
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text("Mencocokkan koordinat dengan lokasi..."),
            ],
          )
        )
      );
    }

    final double uiOpacity = _contentFocusNode.hasFocus ? 0.2 : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9), // Warna Zen
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            _contentFocusNode.unfocus();
          },
          child: Column(
            children: [
              // --- APP BAR FADING ---
              AnimatedOpacity(
                opacity: uiOpacity,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off, 
                        color: _isOnline ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            const Text("Zen Editor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (_isLoading)
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            if (_isOnline) ...[
                              if (widget.draftData?['status'] == 'PUBLISHED')
                                TextButton(
                                  onPressed: () => _submitJournal(publishNow: false),
                                  child: const Text("Perbarui", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                )
                              else ...[
                                TextButton(
                                  onPressed: () => _submitJournal(publishNow: false),
                                  child: const Text("Simpan Draf", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                ),
                                TextButton(
                                  onPressed: () => _submitJournal(publishNow: true),
                                  child: const Text("Terbitkan", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ] else
                              TextButton(
                                onPressed: () => _submitJournal(publishNow: false),
                                child: const Text("Simpan ke Saku", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- BODY CONTENT ---
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  children: [
                    // Kotak Media (Photo Grid)
                    _buildMediaGrid(),
                    
                    // Auto-Context Injection (📍 Candi Prambanan • 16.30 WIB)
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          "${_matchedLocation!['name']} • ${_getFormattedTime()}",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Blok Tulisan Singkat
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 20, 
                        height: 1.6, 
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _randomPrompt,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          height: 1.6
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Ruang lega di bawah agar nyaman scroll
                  ],
                ),
              ),

              // --- FOOTER THEME FADING ---
              AnimatedOpacity(
                opacity: uiOpacity,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                    ]
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _themes.map((theme) {
                        bool isSelected = _selectedTheme == theme;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(theme, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black54)),
                            selected: isSelected,
                            selectedColor: Colors.green,
                            backgroundColor: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedTheme = theme);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
