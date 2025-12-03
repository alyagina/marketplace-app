// lib/models/product_model.dart
class Product {
  final int id;
  final int? userId; // <- baru
  final String name;
  final String? category;
  final String? description;
  final int? price;
  final int? offerPrice;
  final int? quantity;
  final String? image;
  final String? status; // <- baru

  Product({
    required this.id,
    this.userId,
    required this.name,
    this.category,
    this.description,
    this.price,
    this.offerPrice,
    this.quantity,
    this.image,
    this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? ''),
      name: json['name'] ?? '',
      category: json['category'],
      description: json['description'],
      price: json['price'] is int
          ? json['price']
          : int.tryParse(json['price'].toString()),
      offerPrice: json['offer_price'] is int
          ? json['offer_price']
          : int.tryParse(json['offer_price']?.toString() ?? ''),
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.tryParse(json['quantity']?.toString() ?? ''),
      image: json['image'],
      status: json['status'],
    );
  }
}
