import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/data/food_mela_data.dart';
import 'package:food_track/core/state/food_mela_state.dart';
import 'package:food_track/features/home/widgets/food_item_card.dart';
import 'package:food_track/core/utils/routes.dart';

class HomeScreen extends StatefulWidget {
  final FoodMelaState state;

  const HomeScreen({super.key, required this.state});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _showGoogleLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Delivery Location 📍',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Google Location Search Bar
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: FoodMelaaColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onSubmitted: (query) {
                            if (query.isNotEmpty) {
                              widget.state.setAddress('📍 $query, Bhubaneswar');
                              Navigator.pop(context);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search city, street, or landmark on Google Maps...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // GPS Auto-Detect Current Location Button
                GestureDetector(
                  onTap: () async {
                    setModalState(() {});
                    widget.state.simulateGpsLocationDetection();
                    await Future.delayed(const Duration(milliseconds: 1300));
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FoodMelaaColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FoodMelaaColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        widget.state.isDetectingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: FoodMelaaColors.primary),
                              )
                            : const Icon(Icons.my_location_rounded, color: FoodMelaaColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.state.isDetectingLocation ? 'Detecting GPS Location...' : 'Use Current GPS Location 🎯',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary),
                              ),
                              Text(
                                'Using Google Maps GPS auto-detection',
                                style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: FoodMelaaColors.primary),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'SAVED ADDRESSES',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: ListView(
                    children: [
                      _buildSavedAddressOption('Home', 'Laxmi Vihar, Saheed Nagar, Bhubaneswar', Icons.home_rounded),
                      _buildSavedAddressOption('Work', 'Infocity, Patia, Bhubaneswar', Icons.work_rounded),
                      _buildSavedAddressOption('Gym', 'Jaydev Vihar, Janpath, Bhubaneswar', Icons.fitness_center_rounded),
                      _buildSavedAddressOption('Other', 'KIIT Square, Patia, Bhubaneswar', Icons.location_city_rounded),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedAddressOption(String tag, String address, IconData icon) {
    final isSelected = widget.state.selectedAddress == address;
    return ListTile(
      leading: Icon(icon, color: isSelected ? FoodMelaaColors.primary : Colors.grey.shade600),
      title: Text(tag, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(address, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: FoodMelaaColors.primary) : null,
      onTap: () {
        widget.state.setAddress(address);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, child) {
        // Unified Search across Cooked Food + Fresh & Raw Essentials
        final filteredFoodItems = FoodMelaData.allFoodItems.where((item) {
          if (widget.state.isVegOnly && !item.isVeg) return false;
          if (widget.state.selectedCategoryKey != 'all') {
            if (widget.state.selectedCategoryKey == 'fresh_raw' && !item.isRawItem) {
              return false;
            } else if (widget.state.selectedCategoryKey != 'fresh_raw' && item.category != widget.state.selectedCategoryKey) {
              return false;
            }
          }
          if (widget.state.searchQuery.isNotEmpty &&
              !item.name.toLowerCase().contains(widget.state.searchQuery.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        final freshTodayItems = FoodMelaData.allFoodItems.where((i) {
          if (widget.state.isVegOnly && !i.isVeg) return false;
          return i.isFreshToday;
        }).toList();

        final cookedFoodItems = FoodMelaData.allFoodItems.where((i) {
          if (widget.state.isVegOnly && !i.isVeg) return false;
          return !i.isRawItem;
        }).toList();

        return Scaffold(
          backgroundColor: FoodMelaaColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand Header & Google Location Selector
                      GestureDetector(
                        onTap: _showGoogleLocationPicker,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: FoodMelaaColors.primary, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'FOOD MELA',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: FoodMelaaColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '• Everything delivered to your door',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: FoodMelaaColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.state.selectedAddress,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: FoodMelaaColors.textDark,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const Icon(Icons.keyboard_arrow_down_rounded, color: FoodMelaaColors.textDark, size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Veg Filter Toggle Button
                              GestureDetector(
                                onTap: () => widget.state.toggleVegOnly(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: widget.state.isVegOnly ? FoodMelaaColors.vegGreen : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: widget.state.isVegOnly ? FoodMelaaColors.vegGreen : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.eco_rounded,
                                        size: 14,
                                        color: widget.state.isVegOnly ? Colors.white : FoodMelaaColors.vegGreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'VEG',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: widget.state.isVegOnly ? Colors.white : FoodMelaaColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Unified Search Bar (Cooked Food + Fresh & Raw)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: FoodMelaaColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: FoodMelaaColors.borderGrey),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: FoodMelaaColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) => widget.state.setSearchQuery(val),
                                  style: GoogleFonts.inter(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Search food or raw items (Biryani, Egg, Tomato, Chicken)...',
                                    hintStyle: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textGrey),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    widget.state.setSearchQuery('');
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // CATEGORIES ROW (Cooked Food + Fresh & Raw Essentials)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Categories',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: FoodMelaaColors.textDark,
                              ),
                            ),
                            if (widget.state.selectedCategoryKey != 'all')
                              TextButton(
                                onPressed: () => widget.state.selectCategory('all'),
                                child: Text('Show All', style: GoogleFonts.poppins(fontSize: 12, color: FoodMelaaColors.primary)),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 96,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: FoodMelaData.categories.length,
                          itemBuilder: (context, index) {
                            final cat = FoodMelaData.categories[index];
                            final isSelected = widget.state.selectedCategoryKey == cat.key;
                            return GestureDetector(
                              onTap: () => widget.state.selectCategory(cat.key),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? FoodMelaaColors.primary
                                            : (cat.isRaw ? Colors.green.shade50 : Colors.white),
                                        border: Border.all(
                                          color: isSelected
                                              ? FoodMelaaColors.primary
                                              : (cat.isRaw ? Colors.green.shade300 : Colors.grey.shade300),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(cat.icon, style: const TextStyle(fontSize: 26)),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cat.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? FoodMelaaColors.primary : FoodMelaaColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // SPECIAL BANNER: SWEETS & PANEER WHOLESALE SALE 🍨🧀
                      if (widget.state.selectedCategoryKey == 'all' && widget.state.searchQuery.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.pink.shade700, Colors.deepOrange],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Text('🍨', style: TextStyle(fontSize: 36)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow.shade400,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '🏷️ CHEAPEST WHOLESALE GUARANTEE',
                                          style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fresh Sweets & Soft Malai Paneer 🍨🧀',
                                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                                      ),
                                      Text(
                                        'Hot Gulab Jamun @ ₹10 • Rasgulla @ ₹12 • Pure Paneer @ ₹90 wholesale!',
                                        style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // SECTION 1: FRESH TODAY 🥬
                      if (widget.state.selectedCategoryKey == 'all' && widget.state.searchQuery.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Text(
                                'Fresh Today 🥬',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Farm & Meat Fresh',
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 210,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: freshTodayItems.length,
                            itemBuilder: (context, index) {
                              final item = freshTodayItems[index];
                              return _buildHorizontalItemCard(item);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // SECTION 2: COOKED FOOD 🍛
                      if (widget.state.selectedCategoryKey == 'all' && widget.state.searchQuery.isEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Cooked Food 🍛',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: FoodMelaaColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: cookedFoodItems.length,
                            itemBuilder: (context, index) {
                              final item = cookedFoodItems[index];
                              return _buildHorizontalItemCard(item);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // SECTION 3: FOOD + FRESH ESSENTIALS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          widget.state.selectedCategoryKey == 'all'
                              ? 'Food + Fresh Essentials (${filteredFoodItems.length})'
                              : 'Products (${filteredFoodItems.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FoodMelaaColors.textDark,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Products List Feed
                      filteredFoodItems.isEmpty
                          ? Container(
                              height: 180,
                              alignment: Alignment.center,
                              child: Text(
                                'No items found matching your search.',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredFoodItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredFoodItems[index];
                                return FoodItemCard(
                                  item: item,
                                  state: widget.state,
                                );
                              },
                            ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),

                // Floating Live Cart Bar Key
                if (widget.state.totalCartCount > 0)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamed(AppRoutes.cart, arguments: widget.state);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: FoodMelaaColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: FoodMelaaColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.state.totalCartCount} ITEMS IN CART',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '₹${widget.state.grandTotal.toInt()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  'VIEW CART',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalItemCard(FoodItem item) {
    final currentUnit = widget.state.getSelectedUnit(item);
    final qty = widget.state.getItemQuantity(item.id, currentUnit);

    return Container(
      width: 155,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              item.image,
              height: 95,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 95,
                width: double.infinity,
                color: Colors.orange.shade50,
                child: const Icon(Icons.fastfood_rounded, color: FoodMelaaColors.primary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.isRawItem ? '₹${item.price.toInt()} / ${item.unit}' : '₹${item.price.toInt()}',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: FoodMelaaColors.primary),
                ),
                const SizedBox(height: 4),
                qty == 0
                    ? SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => widget.state.addItemToCart(item.id, currentUnit),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FoodMelaaColors.primary,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('ADD', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      )
                    : Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: FoodMelaaColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FoodMelaaColors.primary),
                        ),
                        child: Text(
                          '$qty IN CART',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
