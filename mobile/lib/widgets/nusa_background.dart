import 'package:flutter/material.dart';

class NusaBackground extends StatelessWidget {
  final Widget child; // Widget apapun yang mau ditimpa di atas background ini
  
  const NusaBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50), // Warna dasar gelap
        image: DecorationImage(
          // Ganti bagian NetworkImage menjadi seperti ini:
          image: const NetworkImage('https://images.unsplash.com/photo-1555899434-94d1368aa7af?q=80&w=1080&auto=format&fit=crop'), // Ini foto Gunung Bromo
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5), // Efek redup agar teks selalu terbaca
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}