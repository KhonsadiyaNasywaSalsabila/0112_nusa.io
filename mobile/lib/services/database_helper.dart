import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nusa_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 3, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE draft_journals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        locationId TEXT NOT NULL,
        rootJournalId TEXT,
        content TEXT NOT NULL,
        themeTag TEXT NOT NULL,
        latitudeCaptured REAL NOT NULL,
        longitudeCaptured REAL NOT NULL,
        isMocked INTEGER DEFAULT 0,
        imagePaths TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE locations_cache (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        geofenceRadius REAL NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE draft_journals ADD COLUMN rootJournalId TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE draft_journals ADD COLUMN isMocked INTEGER DEFAULT 0');
    }
  }

  // --- Fungsi untuk Locations Cache ---
  Future<void> cacheLocations(List<dynamic> locations) async {
    final db = await instance.database;
    // Mulai transaksi untuk memastikan cache bersih lalu diisi yang baru
    await db.transaction((txn) async {
      await txn.delete('locations_cache');
      for (var loc in locations) {
        // Mendukung objek LocationModel langsung atau Map
        if (loc is Map) {
          await txn.insert('locations_cache', {
            'id': loc['id'],
            'name': loc['name'],
            'latitude': loc['latitude'] ?? loc['lat'], 
            'longitude': loc['longitude'] ?? loc['lng'], 
            'geofenceRadius': loc['geofenceRadius'] ?? 50.0 
          });
        } else {
          // Asumsi bahwa ini adalah objek LocationModel
          await txn.insert('locations_cache', {
            'id': loc.id,
            'name': loc.name,
            'latitude': loc.latitude, 
            'longitude': loc.longitude, 
            'geofenceRadius': loc.geofenceRadius 
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getLocationsCache() async {
    final db = await instance.database;
    return await db.query('locations_cache');
  }

  // --- Fungsi untuk Draft Journals (Mode Offline) ---
  Future<int> insertDraft(Map<String, dynamic> draft) async {
    final db = await instance.database;
    return await db.insert('draft_journals', draft);
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    final db = await instance.database;
    return await db.query('draft_journals');
  }

  Future<int> updateDraft(int id, Map<String, dynamic> draft) async {
    final db = await instance.database;
    return await db.update('draft_journals', draft, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteDraft(int id) async {
    final db = await instance.database;
    return await db.delete('draft_journals', where: 'id = ?', whereArgs: [id]);
  }
}