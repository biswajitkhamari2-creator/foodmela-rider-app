import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/data/food_track_data.dart';

class RestaurantDetailScreen extends StatelessWidget {
  final RestaurantModel? restaurant;

  const RestaurantDetailScreen({super.key, this.restaurant});

  @override
  Widget build(BuildContext context) {
    final r = restaurant ??
        (ModalRoute.of(context)?.settings.arguments as RestaurantModel?) ??
        FoodTrackData.restaurants.first;

    final items = FoodTrackData.menuItems[r.id] ?? FoodTrackData.menuItems['1']!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                r.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.logo, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text(
                        r.name,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '★ ${r.rating}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.cuisine, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('📍 ${r.address} • ${r.time}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary)),

                  const SizedBox(height: 20),
                  Text(
                    'Recommended Dishes',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          item.image,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey.shade200),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: item.isVeg ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.name,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${item.price.toInt()}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${item.name} added to cart!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('+ ADD'),
                      ),
                    ],
                  ),
                );
              },
              childCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}
