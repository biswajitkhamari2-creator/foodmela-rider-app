import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/data/food_track_data.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favs = FoodTrackData.restaurants.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favorites ❤️',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: favs.length,
                  itemBuilder: (context, index) {
                    final r = favs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Text(r.logo, style: const TextStyle(fontSize: 32)),
                        title: Text(r.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        subtitle: Text(r.cuisine, style: GoogleFonts.inter(fontSize: 12)),
                        trailing: const Icon(Icons.favorite_rounded, color: Colors.red),
                        onTap: () {
                          Navigator.of(context).pushNamed('/restaurant-details', arguments: r);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
