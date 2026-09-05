// Food Mela Data — All food items and categories

// ─── FOOD ITEM MODEL ──────────────────────────────────────────────────────────
class FoodItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final double rating;
  final String image;
  final bool isVeg;
  final bool isRawItem;
  final String unit;
  final List<String> unitOptions;
  final String? freshnessTag;
  final bool isPopular;
  final bool isBestDeal;
  final bool isFreshToday;
  final String? dealText;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.image,
    required this.isVeg,
    this.isRawItem = false,
    this.unit = 'portion',
    this.unitOptions = const ['1 portion'],
    this.freshnessTag,
    this.isPopular = false,
    this.isBestDeal = false,
    this.isFreshToday = false,
    this.dealText,
  });
}

// ─── CATEGORY MODEL ───────────────────────────────────────────────────────────
class FoodMelaCategory {
  final String name;
  final String icon;
  final String key;
  final bool isRaw;

  const FoodMelaCategory({
    required this.name,
    required this.icon,
    required this.key,
    this.isRaw = false,
  });
}

// ─── FOOD MELA DATA ───────────────────────────────────────────────────────────
class FoodMelaData {
  // Categories
  static const List<FoodMelaCategory> categories = [
    FoodMelaCategory(name: 'All', icon: '🍽️', key: 'all'),
    FoodMelaCategory(name: 'Cooked Food', icon: '🍛', key: 'cooked_food'),
    FoodMelaCategory(name: 'Non-Veg', icon: '🍗', key: 'non_veg'),
    FoodMelaCategory(name: 'Sweets', icon: '🍮', key: 'sweets'),
    FoodMelaCategory(name: 'Snacks', icon: '🥙', key: 'snacks'),
    FoodMelaCategory(name: 'Vegetables', icon: '🥦', key: 'vegetables', isRaw: true),
    FoodMelaCategory(name: 'Fruits', icon: '🍎', key: 'fruits', isRaw: true),
    FoodMelaCategory(name: 'Grocery', icon: '🛒', key: 'grocery', isRaw: true),
    FoodMelaCategory(name: 'Dairy', icon: '🥛', key: 'dairy', isRaw: true),
    FoodMelaCategory(name: 'Eggs & Meat', icon: '🥚', key: 'eggs_meat', isRaw: true),
  ];

  // All Food Items
  static const List<FoodItem> allFoodItems = [
    // ── COOKED FOOD ────────────────────────────────────────────────────────────
    FoodItem(
      id: 'cf1',
      name: 'Chicken Biryani',
      category: 'cooked_food',
      price: 220,
      rating: 4.8,
      image: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&h=400&fit=crop',
      isVeg: false,
      isPopular: true,
      freshnessTag: '🔥 Bestseller',
    ),
    FoodItem(
      id: 'cf2',
      name: 'Paneer Butter Masala',
      category: 'cooked_food',
      price: 180,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600&h=400&fit=crop',
      isVeg: true,
      isPopular: true,
      freshnessTag: '⭐ Chef Special',
    ),
    FoodItem(
      id: 'cf3',
      name: 'Dal Makhani',
      category: 'cooked_food',
      price: 150,
      rating: 4.5,
      image: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&h=400&fit=crop',
      isVeg: true,
      freshnessTag: '🌿 Pure Veg',
    ),
    FoodItem(
      id: 'cf4',
      name: 'Mutton Curry',
      category: 'non_veg',
      price: 280,
      rating: 4.7,
      image: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600&h=400&fit=crop',
      isVeg: false,
      isFreshToday: true,
      freshnessTag: '🔥 Fresh Today',
    ),
    FoodItem(
      id: 'cf5',
      name: 'Fish Curry',
      category: 'non_veg',
      price: 240,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=400&fit=crop',
      isVeg: false,
      isFreshToday: true,
      freshnessTag: '🐟 Fresh Catch',
    ),

    // ── SWEETS ─────────────────────────────────────────────────────────────────
    FoodItem(
      id: 'sw1',
      name: 'Rasgulla (6 pcs)',
      category: 'sweets',
      price: 80,
      rating: 4.7,
      image: 'https://images.unsplash.com/photo-1601303516534-61dcef5bc3c5?w=600&h=400&fit=crop',
      isVeg: true,
      isPopular: true,
      freshnessTag: '🍬 Bengali Special',
    ),
    FoodItem(
      id: 'sw2',
      name: 'Gulab Jamun (6 pcs)',
      category: 'sweets',
      price: 70,
      rating: 4.5,
      image: 'https://images.unsplash.com/photo-1625961332071-f1673bbc4e78?w=600&h=400&fit=crop',
      isVeg: true,
      isPopular: true,
    ),
    FoodItem(
      id: 'sw3',
      name: 'Kheer (250ml)',
      category: 'sweets',
      price: 60,
      rating: 4.4,
      image: 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&h=400&fit=crop',
      isVeg: true,
    ),

    // ── SNACKS ─────────────────────────────────────────────────────────────────
    FoodItem(
      id: 'sn1',
      name: 'Samosa (4 pcs)',
      category: 'snacks',
      price: 40,
      rating: 4.5,
      image: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&h=400&fit=crop',
      isVeg: true,
      isPopular: true,
    ),
    FoodItem(
      id: 'sn2',
      name: 'Aloo Tikki (4 pcs)',
      category: 'snacks',
      price: 50,
      rating: 4.3,
      image: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&h=400&fit=crop',
      isVeg: true,
    ),

    // ── VEGETABLES (Raw) ───────────────────────────────────────────────────────
    FoodItem(
      id: 'vg1',
      name: 'Fresh Tomato',
      category: 'vegetables',
      price: 40,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1546470427-e26264be0b0d?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg', '2 kg', '5 kg'],
      isFreshToday: true,
      freshnessTag: '🍅 Farm Fresh Today',
    ),
    FoodItem(
      id: 'vg2',
      name: 'Potato',
      category: 'vegetables',
      price: 30,
      rating: 4.4,
      image: 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['1 kg', '2 kg', '5 kg'],
      isFreshToday: true,
    ),
    FoodItem(
      id: 'vg3',
      name: 'Onion',
      category: 'vegetables',
      price: 35,
      rating: 4.3,
      image: 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['1 kg', '2 kg', '5 kg'],
    ),
    FoodItem(
      id: 'vg4',
      name: 'Brinjal (Baingan)',
      category: 'vegetables',
      price: 30,
      rating: 4.5,
      image: 'https://images.unsplash.com/photo-1615485500704-8e990f9900f7?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg', '2 kg'],
      isFreshToday: true,
      freshnessTag: '🌱 Farm Fresh',
    ),
    FoodItem(
      id: 'vg5',
      name: 'Cabbage (Pattagobi)',
      category: 'vegetables',
      price: 30,
      rating: 4.4,
      image: 'https://images.unsplash.com/photo-1594282486552-05b4d80fbb9f?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg', '2 kg'],
      isFreshToday: true,
      freshnessTag: '🥬 Fresh Harvest',
    ),
    FoodItem(
      id: 'vg6',
      name: 'Cauliflower (Phoolgobi)',
      category: 'vegetables',
      price: 35,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1568584711075-3d021a7c3ca3?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg', '2 kg'],
      isFreshToday: true,
      freshnessTag: '🥦 Fresh Today',
    ),
    FoodItem(
      id: 'vg7',
      name: 'Lady Finger (Bhindi)',
      category: 'vegetables',
      price: 40,
      rating: 4.3,
      image: 'https://images.unsplash.com/photo-1425543103986-22abb7d7e8d2?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg'],
    ),

    // ── FRUITS ─────────────────────────────────────────────────────────────────
    FoodItem(
      id: 'fr1',
      name: 'Banana (Dozen)',
      category: 'fruits',
      price: 50,
      rating: 4.5,
      image: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'dozen',
      unitOptions: ['1 dozen', '2 dozen'],
      isFreshToday: true,
      freshnessTag: '🍌 Fresh Import',
    ),
    FoodItem(
      id: 'fr2',
      name: 'Apple',
      category: 'fruits',
      price: 160,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg', '2 kg'],
    ),

    // ── GROCERY ────────────────────────────────────────────────────────────────
    FoodItem(
      id: 'gr1',
      name: 'Basmati Rice (India Gate)',
      category: 'grocery',
      price: 180,
      rating: 4.7,
      image: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['1 kg', '2 kg', '5 kg', '10 kg'],
      isBestDeal: true,
      dealText: '10% OFF',
    ),
    FoodItem(
      id: 'gr2',
      name: 'Refined Oil (Fortune)',
      category: 'grocery',
      price: 145,
      rating: 4.5,
      image: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'litre',
      unitOptions: ['1 litre', '2 litre', '5 litre'],
    ),

    // ── DAIRY ──────────────────────────────────────────────────────────────────
    FoodItem(
      id: 'da1',
      name: 'Full Cream Milk (Amul)',
      category: 'dairy',
      price: 62,
      rating: 4.8,
      image: 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: 'litre',
      unitOptions: ['500ml', '1 litre', '2 litre'],
      isFreshToday: true,
      freshnessTag: '🥛 Fresh Daily',
    ),
    FoodItem(
      id: 'da2',
      name: 'Paneer (Fresh)',
      category: 'dairy',
      price: 80,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600&h=400&fit=crop',
      isVeg: true,
      isRawItem: true,
      unit: '200g',
      unitOptions: ['200g', '500g', '1 kg'],
      isFreshToday: true,
      freshnessTag: '🧀 Made Today',
    ),

    // ── EGGS & MEAT ────────────────────────────────────────────────────────────
    FoodItem(
      id: 'em1',
      name: 'Farm Eggs',
      category: 'eggs_meat',
      price: 72,
      rating: 4.7,
      image: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=600&h=400&fit=crop',
      isVeg: false,
      isRawItem: true,
      unit: 'dozen',
      unitOptions: ['6 eggs', '12 eggs', '30 eggs'],
      isFreshToday: true,
      freshnessTag: '🐣 Farm Fresh',
    ),
    FoodItem(
      id: 'em2',
      name: 'Chicken (Boneless)',
      category: 'eggs_meat',
      price: 320,
      rating: 4.6,
      image: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=600&h=400&fit=crop',
      isVeg: false,
      isRawItem: true,
      unit: 'kg',
      unitOptions: ['500g', '1 kg', '2 kg'],
      isFreshToday: true,
      freshnessTag: '🍗 Cleaned & Cut',
    ),
  ];
}
