import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/data/food_track_data.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isVegOnly = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = FoodTrackData.restaurants.where((r) {
      final matchesQuery = r.name.toLowerCase().contains(_query.toLowerCase()) ||
          r.cuisine.toLowerCase().contains(_query.toLowerCase());
      final matchesVeg = !_isVegOnly || r.isVeg;
      return matchesQuery && matchesVeg;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Search Bar & Filter Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search restaurants or dishes...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) => setState(() => _query = val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _isVegOnly = !_isVegOnly),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isVegOnly ? const Color(0xFF16A34A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isVegOnly ? const Color(0xFF16A34A) : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 16,
                            color: _isVegOnly ? Colors.white : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Veg',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isVegOnly ? Colors.white : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search Results
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No restaurants found matching "$_query"',
                          style: GoogleFonts.inter(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: Text(r.logo, style: const TextStyle(fontSize: 28)),
                              title: Text(
                                r.name,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                r.cuisine,
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '★ ${r.rating}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  '/restaurant-details',
                                  arguments: r,
                                );
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
