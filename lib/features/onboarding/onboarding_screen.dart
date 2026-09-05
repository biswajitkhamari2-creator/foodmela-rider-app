import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.restaurant_menu_rounded,
      title: 'Discover Amazing Food',
      description:
          'Explore a world of culinary delights from the best restaurants near you, delivered right to your doorstep.',
      color: AppColors.primary,
      accentColor: AppColors.accent,
    ),
    _OnboardingPage(
      icon: Icons.delivery_dining_rounded,
      title: 'Lightning Fast Delivery',
      description:
          'Our dedicated riders ensure your food arrives hot and fresh. Track every step of the journey in real time.',
      color: AppColors.secondary,
      accentColor: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.stars_rounded,
      title: 'Rewards With Every Bite',
      description:
          'Earn FoodTrack points on every order. Unlock exclusive deals, free delivery, and special surprises.',
      color: AppColors.accent,
      accentColor: AppColors.secondary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  void _onSkip() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: size.height * 0.55,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_currentPage].color,
                  _pages[_currentPage].color.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], size);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 32 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _pages[_currentPage].color
                                  : AppColors.textTertiary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pages[_currentPage].color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 4,
                            shadowColor:
                                _pages[_currentPage].color.withValues(alpha: 0.4),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Continue',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 70,
              color: page.color,
            ),
          ),
          const Spacer(),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color accentColor;

  _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.accentColor,
  });
}
