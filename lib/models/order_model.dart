class OrderModel {
  final int id;
  final int buyerId;
  final int sellerId;
  final int productId;
  final int totalPrice;
  final String paymentMethod;
  final String status;

  final String shippingPhone;
  final String shippingStreet;
  final String shippingCity;
  final String shippingState;
  final String shippingPostalCode;
  final String shippingCountry;

  final String createdAt;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.totalPrice,
    required this.paymentMethod,
    required this.status,
    required this.shippingPhone,
    required this.shippingStreet,
    required this.shippingCity,
    required this.shippingState,
    required this.shippingPostalCode,
    required this.shippingCountry,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      buyerId: json['user_beli'],
      sellerId: json['user_jual'],
      productId: json['product_id'],
      totalPrice: json['total_price'],
      paymentMethod: json['payment_method'],
      status: json['status'],
      shippingPhone: json['shipping_phone'],
      shippingStreet: json['shipping_street'],
      shippingCity: json['shipping_city'],
      shippingState: json['shipping_state'],
      shippingPostalCode: json['shipping_postal_code'],
      shippingCountry: json['shipping_country'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
