import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/state/food_mela_state.dart';
import 'package:food_track/features/home/home_screen.dart';
import 'package:food_track/features/cart/cart_screen.dart';
import 'package:food_track/features/account/orders_screen.dart';
import 'package:food_track/features/profile/profile_screen.dart';

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _currentIndex = 0;
  late final FoodMelaState _appState;

  @override
  void initState() {
    super.initState();
    _appState = FoodMelaState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(state: _appState),
      CartScreen(state: _appState),
      OrdersScreen(state: _appState),
      const ProfileScreen(),
    ];

    return AnimatedBuilder(
      animation: _appState,
      builder: (context, child) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: FoodMelaaColors.primary,
              unselectedItemColor: FoodMelaaColors.textGrey,
              selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.rice_bowl_rounded),
                  activeIcon: Icon(Icons.rice_bowl_rounded, color: FoodMelaaColors.primary),
                  label: 'Food',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    label: Text('${_appState.totalCartCount}'),
                    isLabelVisible: _appState.totalCartCount > 0,
                    child: const Icon(Icons.shopping_bag_rounded),
                  ),
                  activeIcon: Badge(
                    label: Text('${_appState.totalCartCount}'),
                    isLabelVisible: _appState.totalCartCount > 0,
                    child: const Icon(Icons.shopping_bag_rounded, color: FoodMelaaColors.primary),
                  ),
                  label: 'Cart',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_rounded),
                  activeIcon: Icon(Icons.receipt_long_rounded, color: FoodMelaaColors.primary),
                  label: 'Orders',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  activeIcon: Icon(Icons.person_rounded, color: FoodMelaaColors.primary),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
