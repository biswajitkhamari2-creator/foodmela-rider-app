import os

files = {
    'd:/Food_Mela_Master_Project/2_Rider_App/lib/features/rider/rider_wallet_screen.dart': 'rider_wallet_screen.dart',
    'd:/Food_Mela_Master_Project/2_Rider_App/lib/features/rider/incoming_order_screen.dart': 'incoming_order_screen.dart',
    'd:/Food_Mela_Master_Project/2_Rider_App/lib/features/rider/active_delivery_screen.dart': 'active_delivery_screen.dart',
    'd:/Food_Mela_Master_Project/2_Rider_App/lib/features/rider/rider_login_screen.dart': 'rider_login_screen.dart'
}

for path, name in files.items():
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    if name == 'rider_wallet_screen.dart':
        content = content.replace('Color(0xFF047857), Color(0xFF065F46), Color(0xFF064E3B)', 'Color(0xFF8C5E00), Color(0xFFB8860B), Color(0xFFD4AF37)')
        content = content.replace('Color(0xFF047857).withValues(alpha: 0.35)', 'Color(0xFFD4AF37).withValues(alpha: 0.35)')
        content = content.replace('Color(0xFF0F1115)', 'Color(0xFF12100C)') # surfaceDark
        content = content.replace('Color(0xFFF1F5F9)', 'Color(0xFFFFFBF2)') # goldWash
        content = content.replace('Color(0xFF181B20)', 'Color(0xFF1C1813)') # cardDark
        content = content.replace('Color(0xFF1C1815)', 'Color(0xFF1C1813)') # cardDark
        content = content.replace('Color(0xFF10B981)', 'Color(0xFFD4AF37)') # goldBright
        
        content = content.replace('FoodMelaaColors.riderPrimary', 'Color(0xFFD4AF37)')
        content = content.replace('FoodMelaaColors.riderPrimaryLight', 'Color(0xFFFFF6E0)')
        
        content = content.replace('Color(0xFF059669)', 'Color(0xFF15803D)') # Approved semantic
        
        if 'RiderGold' not in content:
            content = content.replace(\"import 'package:food_track/core/theme/food_melaa_colors.dart';\", \"import 'package:food_track/core/theme/food_melaa_colors.dart';\\nimport 'package:food_track/core/theme/rider_gold.dart';\")
            content = content.replace('FoodMelaaColors.borderLight', 'RiderGold.goldBorder')
            content = content.replace('Colors.white.withOpacity(0.05)', 'RiderGold.borderDark')

    elif name == 'incoming_order_screen.dart':
        content = content.replace('Color(0xFF075E54)', 'Color(0xFF8C5E00)')
        content = content.replace('Color(0xFF054C44)', 'Color(0xFF5C3A00)')
        content = content.replace('Color(0xFF0F3E38)', 'Color(0xFFB8860B)')
        content = content.replace('Color(0xFF0B2D29)', 'Color(0xFFD4AF37)')
        
        # WhatsApp buttons, keeping decline Red (EA0038) and changing accept Green to Gold
        content = content.replace('Color(0xFF25D366)', 'Color(0xFFD4AF37)')
        content = content.replace('Color(0xFF25D366).withValues(alpha: 0.18)', 'Color(0xFFD4AF37).withValues(alpha: 0.18)')
        content = content.replace('Color(0xFF25D366).withValues(alpha: 0.30)', 'Color(0xFFD4AF37).withValues(alpha: 0.30)')
        content = content.replace('Color(0xFF25D366).withValues(alpha: 0.45)', 'Color(0xFFD4AF37).withValues(alpha: 0.45)')

        content = content.replace('Color(0xFF047857)', 'Color(0xFFB8860B)')
        content = content.replace('Color(0xFFA7F3D0)', 'Color(0xFFEAD9A8)')
        content = content.replace('Color(0xFFECFDF5)', 'Color(0xFFFFF6E0)')
        
        content = content.replace('FoodMelaaColors.riderPrimary', 'Color(0xFFD4AF37)')
        content = content.replace('Color(0xFF1C1815)', 'Color(0xFF1C1813)')
        
    elif name == 'active_delivery_screen.dart':
        content = content.replace('Color(0xFF047857), Color(0xFF10B981)', 'Color(0xFF8C5E00), Color(0xFFD4AF37)')
        content = content.replace('Color(0xFF10B981)', 'Color(0xFFD4AF37)')
        content = content.replace('Color(0xFF047857)', 'Color(0xFFB8860B)')
        content = content.replace('Color(0xFF065F46)', 'Color(0xFF8C5E00)')
        content = content.replace('Color(0xFF0F1115)', 'Color(0xFF12100C)') # surfaceDark
        content = content.replace('Color(0xFFF4F7FB)', 'Color(0xFFFFFBF2)') # goldWash
        content = content.replace('Color(0xFF181B20)', 'Color(0xFF1C1813)') # cardDark
        content = content.replace('Color(0xFF1C1815)', 'Color(0xFF1C1813)') # cardDark
        content = content.replace('FoodMelaaColors.riderPrimary', 'Color(0xFFD4AF37)')
        
        if 'RiderGold' not in content:
            content = content.replace(\"import 'package:food_track/core/theme/food_melaa_colors.dart';\", \"import 'package:food_track/core/theme/food_melaa_colors.dart';\\nimport 'package:food_track/core/theme/rider_gold.dart';\")
            content = content.replace('FoodMelaaColors.borderLight', 'RiderGold.goldBorder')
            content = content.replace('Colors.white.withOpacity(0.05)', 'RiderGold.borderDark')

    elif name == 'rider_login_screen.dart':
        content = content.replace('Color(0xFF10B981)', 'Color(0xFFD4AF37)')
        content = content.replace('Color(0xFF047857)', 'Color(0xFF8C5E00)')
        # Already has nice gold for logo and gradients, just replace green buttons

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

print("Redesign applied successfully.")
