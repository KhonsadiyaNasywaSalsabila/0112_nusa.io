import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bookmark_model.dart';

class CsvExporter {
  /// Ekspor daftar bookmark ke file CSV dan tampilkan dialog share
  static Future<String> exportBookmarksToCsv(List<BookmarkModel> bookmarks, String fileName) async {
    try {
      // 1. Siapkan header tabel CSV
      // Menambahkan BOM (Byte Order Mark) \uFEFF agar Excel bisa membaca karakter khusus/UTF-8 dengan benar
      String csvData = '\uFEFFNama Lokasi,Status,Tema Tersedia,Total Jurnal,Tanggal Ditambahkan\n';

      // 2. Susun baris data
      for (var bookmark in bookmarks) {
        // Karena tema ada di dalam jurnal-jurnal lokasi, kita gabungkan dari availableThemes
        final loc = bookmark.location;
        final name = loc?.name.replaceAll(',', ' ') ?? 'Tanpa Nama'; // Hindari koma merusak kolom
        final status = bookmark.status;
        final themes = loc?.availableThemes.join(' & ') ?? '-';
        final journalCount = loc?.journalCount.toString() ?? '0';
        
        // Format tanggal (contoh: 2026-06-25)
        final date = bookmark.createdAt != null 
            ? "\${bookmark.createdAt!.year}-\${bookmark.createdAt!.month.toString().padLeft(2, '0')}-\${bookmark.createdAt!.day.toString().padLeft(2, '0')}"
            : '-';

        csvData += '$name,$status,$themes,$journalCount,$date\n';
      }

      // 3. Dapatkan direktori lokal (Folder Downloads agar mudah dicari di Emulator/HP)
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        // Fallback jika folder Download tidak ditemukan
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String filePath = '${directory!.path}/${fileName}_Data.txt';

      // 4. Buat file secara fisik dan tulis isinya
      final file = File(filePath);
      await file.writeAsString(csvData);

      // 5. Kembalikan lokasi file untuk ditampilkan ke user
      return filePath;

    } catch (e) {
      print("Error exporting to CSV: $e");
      rethrow;
    }
  }
}
