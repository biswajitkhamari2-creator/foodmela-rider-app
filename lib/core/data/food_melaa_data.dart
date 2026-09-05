class FoodMelaaRestaurant {
  final String id;
  final String name;
  final String image;
  final String cuisine;
  final double rating;
  final int reviews;
  final String deliveryTime;
  final String distance;
  final String costForTwo;
  final String? offer;
  final bool isVip;
  final bool isVeg;

  const FoodMelaaRestaurant({
    required this.id,
    required this.name,
    required this.image,
    required this.cuisine,
    required this.rating,
    required this.reviews,
    required this.deliveryTime,
    required this.distance,
    required this.costForTwo,
    this.offer,
    this.isVip = false,
    this.isVeg = false,
  });
}

class FoodMelaaMenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String image;
  final double rating;
  final bool isVeg;
  final String category;
  final bool bestseller;

  const FoodMelaaMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.rating,
    required this.isVeg,
    required this.category,
    this.bestseller = false,
  });
}

class FoodMelaaData {
  static const List<FoodMelaaRestaurant> restaurants = [
    FoodMelaaRestaurant(
      id: '1',
      name: "Haldiram's Sweets & Snacks",
      image: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&h=400&fit=crop&auto=format',
      cuisine: 'North Indian, Mithai, Street Food, Thali',
      rating: 4.5,
      reviews: 8420,
      deliveryTime: '22 min',
      distance: '1.2 km',
      costForTwo: '₹350 for two',
      offer: '50% OFF up to ₹100',
      isVip: true,
      isVeg: true,
    ),
    FoodMelaaRestaurant(
      id: '2',
      name: 'Biryani By Kilo',
      image: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&h=400&fit=crop&auto=format',
      cuisine: 'Hyderabadi Biryani, Kebabs, Mughlai',
      rating: 4.6,
      reviews: 6150,
      deliveryTime: '28 min',
      distance: '2.4 km',
      costForTwo: '₹600 for two',
      offer: 'FLAT ₹120 OFF',
      isVip: true,
      isVeg: false,
    ),
    FoodMelaaRestaurant(
      id: '3',
      name: "Domino's Pizza",
      image: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=400&fit=crop&auto=format',
      cuisine: 'Pizza, Italian, Fast Food, Desserts',
      rating: 4.4,
      reviews: 12400,
      deliveryTime: '20 min',
      distance: '0.9 km',
      costForTwo: '₹400 for two',
      offer: 'EVERYDAY VALUE FROM ₹99',
      isVip: true,
      isVeg: false,
    ),
    FoodMelaaRestaurant(
      id: '4',
      name: 'The Burger Club',
      image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&h=400&fit=crop&auto=format',
      cuisine: 'Burgers, Fries, Shakes, American',
      rating: 4.3,
      reviews: 3200,
      deliveryTime: '25 min',
      distance: '1.8 km',
      costForTwo: '₹300 for two',
      offer: '60% OFF up to ₹120',
      isVip: false,
      isVeg: false,
    ),
    FoodMelaaRestaurant(
      id: '5',
      name: 'Wow! Momo',
      image: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&h=400&fit=crop&auto=format',
      cuisine: 'Momos, Chinese, Tibetan, Fast Food',
      rating: 4.2,
      reviews: 4100,
      deliveryTime: '18 min',
      distance: '1.1 km',
      costForTwo: '₹250 for two',
      offer: 'Buy 1 Get 1 FREE',
      isVip: true,
      isVeg: false,
    ),
  ];

  static final Map<String, List<FoodMelaaMenuItem>> menuItems = {
    '1': const [
      FoodMelaaMenuItem(
        id: 'h1',
        name: 'Special Raj Kachori',
        description: 'Crispy large puri stuffed with sprouts, boiled potatoes, curd, chutneys and sev',
        price: 149,
        image: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&h=300&fit=crop&auto=format',
        rating: 4.8,
        isVeg: true,
        category: 'Chaats',
        bestseller: true,
      ),
      FoodMelaaMenuItem(
        id: 'h2',
        name: 'Special Chole Bhature (2 Pcs)',
        description: 'Spicy chickpeas curry served with 2 fluffy bhaturas, pickles & fried chili',
        price: 189,
        image: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=400&h=300&fit=crop&auto=format',
        rating: 4.7,
        isVeg: true,
        category: 'Main Course',
        bestseller: true,
      ),
    ],
    '2': const [
      FoodMelaaMenuItem(
        id: 'b1',
        name: 'Chicken Dum Biryani (1/2 kg)',
        description: 'Authentic Hyderabadi dum biryani cooked in clay pot with succulent chicken pieces',
        price: 389,
        image: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&h=300&fit=crop&auto=format',
        rating: 4.9,
        isVeg: false,
        category: 'Biryani',
        bestseller: true,
      ),
    ],
  };

  static const List<Map<String, String>> categories = [
    {'name': 'Biryani', 'icon': '🍚'},
    {'name': 'Pizza', 'icon': '🍕'},
    {'name': 'Burger', 'icon': '🍔'},
    {'name': 'North Indian', 'icon': '🍛'},
    {'name': 'Chinese', 'icon': '🍜'},
    {'name': 'Thali', 'icon': '🍱'},
    {'name': 'Cake', 'icon': '🍰'},
  ];
}
