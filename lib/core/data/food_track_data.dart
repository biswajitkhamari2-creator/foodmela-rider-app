class RestaurantModel {
  final String id;
  final String name;
  final String image;
  final String logo;
  final double rating;
  final int reviews;
  final String cuisine;
  final String time;
  final String distance;
  final String price;
  final String? offer;
  final bool isVeg;
  final List<String> tags;
  final String address;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.image,
    required this.logo,
    required this.rating,
    required this.reviews,
    required this.cuisine,
    required this.time,
    required this.distance,
    required this.price,
    this.offer,
    required this.isVeg,
    required this.tags,
    required this.address,
  });
}

class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String image;
  final double rating;
  final bool isVeg;
  final String category;
  final bool bestseller;

  const MenuItemModel({
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

class CartItemModel {
  final MenuItemModel item;
  int quantity;
  final String restaurantId;
  final String restaurantName;

  CartItemModel({
    required this.item,
    required this.quantity,
    required this.restaurantId,
    required this.restaurantName,
  });
}

class CouponModel {
  final String code;
  final String discount;
  final String description;
  final double minOrder;
  final String expiry;
  final String type; // 'percent' | 'flat'
  final double value;

  const CouponModel({
    required this.code,
    required this.discount,
    required this.description,
    required this.minOrder,
    required this.expiry,
    required this.type,
    required this.value,
  });
}

class AddressModel {
  final String id;
  final String type; // 'home' | 'work' | 'other'
  final String label;
  final String address;
  final String? landmark;

  const AddressModel({
    required this.id,
    required this.type,
    required this.label,
    required this.address,
    this.landmark,
  });
}

class OrderModel {
  final String id;
  final String restaurant;
  final String restaurantImage;
  final List<String> items;
  final String date;
  final double amount;
  final String status; // 'delivered' | 'cancelled' | 'active'
  final String? deliveryTime;

  const OrderModel({
    required this.id,
    required this.restaurant,
    required this.restaurantImage,
    required this.items,
    required this.date,
    required this.amount,
    required this.status,
    this.deliveryTime,
  });
}

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final int colorHex;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
  });
}

class FoodTrackData {
  static const List<RestaurantModel> restaurants = [
    RestaurantModel(
      id: '1',
      name: 'The Burger Lab',
      image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&h=400&fit=crop&auto=format',
      logo: '🍔',
      rating: 4.8,
      reviews: 2341,
      cuisine: 'American, Burgers, Wraps',
      time: '20–25 min',
      distance: '1.2 km',
      price: '₹₹',
      offer: '20% OFF up to ₹120',
      isVeg: false,
      tags: ['Trending', 'Popular'],
      address: 'Shop 12, Saheed Nagar, Bhubaneswar',
    ),
    RestaurantModel(
      id: '2',
      name: 'Spice Route',
      image: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&h=400&fit=crop&auto=format',
      logo: '🍛',
      rating: 4.6,
      reviews: 1876,
      cuisine: 'North Indian, Mughlai, Biryani',
      time: '30–35 min',
      distance: '2.1 km',
      price: '₹₹',
      offer: 'Free delivery on orders above ₹299',
      isVeg: false,
      tags: ['Best Seller'],
      address: '45, Janpath, Bhubaneswar',
    ),
    RestaurantModel(
      id: '3',
      name: 'Dragon Palace',
      image: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&h=400&fit=crop&auto=format',
      logo: '🐉',
      rating: 4.5,
      reviews: 987,
      cuisine: 'Chinese, Thai, Pan-Asian',
      time: '25–30 min',
      distance: '1.8 km',
      price: '₹₹',
      offer: '30% OFF up to ₹150',
      isVeg: false,
      tags: ['New'],
      address: '67, Kharvel Nagar, Bhubaneswar',
    ),
    RestaurantModel(
      id: '4',
      name: 'Pizza Paradise',
      image: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=400&fit=crop&auto=format',
      logo: '🍕',
      rating: 4.7,
      reviews: 3102,
      cuisine: 'Pizza, Italian, Pasta',
      time: '25–30 min',
      distance: '0.9 km',
      price: '₹₹₹',
      offer: 'Buy 1 Get 1 FREE',
      isVeg: false,
      tags: ['Popular', 'Top Rated'],
      address: 'Forum Mart, Chandrasekharpur, Bhubaneswar',
    ),
    RestaurantModel(
      id: '5',
      name: 'The Healthy Bowl',
      image: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&h=400&fit=crop&auto=format',
      logo: '🥗',
      rating: 4.4,
      reviews: 654,
      cuisine: 'Salads, Healthy, Wraps',
      time: '20–25 min',
      distance: '1.5 km',
      price: '₹₹',
      offer: '15% OFF',
      isVeg: true,
      tags: ['Veg', 'Healthy'],
      address: 'Unit 4, Nayapalli, Bhubaneswar',
    ),
    RestaurantModel(
      id: '6',
      name: 'Sweet Escape',
      image: 'https://images.unsplash.com/photo-1570197788417-0e82375c9371?w=600&h=400&fit=crop&auto=format',
      logo: '🍰',
      rating: 4.9,
      reviews: 1432,
      cuisine: 'Desserts, Cakes, Ice Cream',
      time: '15–20 min',
      distance: '0.7 km',
      price: '₹₹',
      offer: '25% OFF on first order',
      isVeg: true,
      tags: ['Top Rated', 'Pure Veg'],
      address: 'Inox Square, Bhubaneswar',
    ),
  ];

  static final Map<String, List<MenuItemModel>> menuItems = {
    '1': const [
      MenuItemModel(
        id: 'b1',
        name: 'Classic Smash Burger',
        description: 'Double smashed beef patty, American cheese, pickles, onion, special sauce',
        price: 249,
        image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop&auto=format',
        rating: 4.8,
        isVeg: false,
        category: 'Burgers',
        bestseller: true,
      ),
      MenuItemModel(
        id: 'b2',
        name: 'Spicy Jalapeño Burger',
        description: 'Crispy chicken patty, jalapeños, pepper sauce, lettuce, tomato',
        price: 219,
        image: 'https://images.unsplash.com/photo-1603039914406-05d928ee4f3a?w=400&h=300&fit=crop&auto=format',
        rating: 4.7,
        isVeg: false,
        category: 'Burgers',
      ),
      MenuItemModel(
        id: 'b4',
        name: 'Crispy Fries (Large)',
        description: 'Golden crispy fries with house seasoning',
        price: 99,
        image: 'https://images.unsplash.com/photo-1559611657-28b38b1b28d9?w=400&h=300&fit=crop&auto=format',
        rating: 4.5,
        isVeg: true,
        category: 'Sides',
        bestseller: true,
      ),
    ],
    '2': const [
      MenuItemModel(
        id: 's1',
        name: 'Chicken Dum Biryani',
        description: 'Slow-cooked basmati rice with tender chicken, aromatic spices, caramelized onions',
        price: 349,
        image: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&h=300&fit=crop&auto=format',
        rating: 4.8,
        isVeg: false,
        category: 'Biryani',
        bestseller: true,
      ),
      MenuItemModel(
        id: 's2',
        name: 'Paneer Butter Masala',
        description: 'Soft paneer in rich tomato-cashew gravy, butter, cream',
        price: 289,
        image: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=400&h=300&fit=crop&auto=format',
        rating: 4.7,
        isVeg: true,
        category: 'Main Course',
        bestseller: true,
      ),
    ],
    '4': const [
      MenuItemModel(
        id: 'p1',
        name: 'Margherita Pizza',
        description: 'San Marzano tomato, fresh mozzarella, basil, EVOO',
        price: 349,
        image: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=300&fit=crop&auto=format',
        rating: 4.8,
        isVeg: true,
        category: 'Pizza',
        bestseller: true,
      ),
      MenuItemModel(
        id: 'p2',
        name: 'BBQ Chicken Pizza',
        description: 'Smoky BBQ sauce, chicken, red onion, jalapeños',
        price: 449,
        image: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=400&h=300&fit=crop&auto=format',
        rating: 4.7,
        isVeg: false,
        category: 'Pizza',
        bestseller: true,
      ),
    ],
  };

  static const List<CategoryModel> categories = [
    CategoryModel(id: '1', name: 'Burgers', icon: '🍔', colorHex: 0xFFFFF3E0),
    CategoryModel(id: '2', name: 'Pizza', icon: '🍕', colorHex: 0xFFFCE4EC),
    CategoryModel(id: '3', name: 'Indian', icon: '🍛', colorHex: 0xFFFFF8E1),
    CategoryModel(id: '4', name: 'Chinese', icon: '🍜', colorHex: 0xFFE8F5E9),
    CategoryModel(id: '5', name: 'Healthy', icon: '🥗', colorHex: 0xFFF3E5F5),
    CategoryModel(id: '6', name: 'Chicken', icon: '🍗', colorHex: 0xFFFBE9E7),
    CategoryModel(id: '7', name: 'Desserts', icon: '🍰', colorHex: 0xFFE0F7FA),
    CategoryModel(id: '8', name: 'Biryani', icon: '🍚', colorHex: 0xFFFFF9C4),
  ];

  static const List<CouponModel> coupons = [
    CouponModel(
      code: 'FIRST50',
      discount: '50% OFF',
      description: '50% off up to ₹150 on your first order',
      minOrder: 199,
      expiry: '31 Aug 2026',
      type: 'percent',
      value: 50,
    ),
    CouponModel(
      code: 'SAVE100',
      discount: '₹100 OFF',
      description: 'Flat ₹100 off on orders above ₹499',
      minOrder: 499,
      expiry: '15 Sep 2026',
      type: 'flat',
      value: 100,
    ),
    CouponModel(
      code: 'FREEDELIVERY',
      discount: 'Free Delivery',
      description: 'Free delivery on any order above ₹199',
      minOrder: 199,
      expiry: '20 Aug 2026',
      type: 'flat',
      value: 40,
    ),
  ];

  static const List<AddressModel> addresses = [
    AddressModel(
      id: '1',
      type: 'home',
      label: 'Home',
      address: '42, Laxmi Vihar, Nayapalli, Bhubaneswar — 751012',
      landmark: 'Near DPS School',
    ),
    AddressModel(
      id: '2',
      type: 'work',
      label: 'Office',
      address: 'Infocity, Patia, Bhubaneswar — 751024',
      landmark: 'Mindtree Campus, Gate 2',
    ),
  ];

  static const List<OrderModel> orders = [
    OrderModel(
      id: 'FT2406001',
      restaurant: 'The Burger Lab',
      restaurantImage: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=100&h=100&fit=crop&auto=format',
      items: ['Classic Smash Burger', 'Crispy Fries (Large)'],
      date: 'Today, 12:45 PM',
      amount: 348,
      status: 'active',
      deliveryTime: '12 min',
    ),
    OrderModel(
      id: 'FT2405982',
      restaurant: 'Pizza Paradise',
      restaurantImage: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=100&h=100&fit=crop&auto=format',
      items: ['Margherita Pizza', 'BBQ Chicken Pizza'],
      date: 'Yesterday, 8:30 PM',
      amount: 798,
      status: 'delivered',
    ),
  ];
}
