import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';
import '../models/product_model.dart';
import 'order_detail_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  Future<List<OrderModel>>? _futureOrders;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserAndOrders();
  }

  final Map<int, Future<Product>> _productFutures = {};

  Future<Product> _getProduct(int productId) {
    _productFutures.putIfAbsent(productId, () async {
      final url = Uri.parse('http://mortava.biz.id/api/products/$productId');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return Product.fromJson(body);
        } else {
          throw Exception('Format produk tidak sesuai');
        }
      } else {
        throw Exception('Gagal memuat produk ($productId)');
      }
    });

    return _productFutures[productId]!;
  }

  Future<void> _loadUserAndOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (!mounted) return;

    if (userId == null) {
      setState(() {
        _futureOrders = Future.error('User belum login');
      });
      return;
    }

    setState(() {
      _userId = userId;
      _futureOrders = _fetchOrders();
    });
  }

  Future<List<OrderModel>> _fetchOrders() async {
    if (_userId == null) {
      throw Exception('User belum login');
    }

    final url = Uri.parse("http://mortava.biz.id/api/orders/buy/$_userId");

    final response = await http.get(
      url,
      headers: {"Accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body is List) {
        return body
            .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception("Format API tidak sesuai (harus list)");
      }
    } else {
      throw Exception("Gagal memuat pesanan (${response.statusCode})");
    }
  }

  // BARU DI UPDATE

  Future<void> _cancelOrder(int orderId) async {
    final url = Uri.parse('http://mortava.biz.id/api/orders/$orderId/cancel');

    try {
      final response = await http.patch(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        // refresh pesanan
        setState(() {
          _futureOrders = _fetchOrders();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan berhasil dibatalkan')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan pesanan (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _markOrderAsCompleted(int orderId) async {
    final url = Uri.parse('http://mortava.biz.id/api/orders/$orderId/complete');

    try {
      final response = await http.patch(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        // reload daftar pesanan
        setState(() {
          _futureOrders = _fetchOrders();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan ditandai selesai')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyelesaikan pesanan (${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pesanan Saya")),
      body: _futureOrders == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<OrderModel>>(
              future: _futureOrders,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return const Center(child: Text("Belum ada pesanan"));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final o = orders[index];

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailPage(orderId: o.id),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==========================
                              //   Seller username (baru)
                              // ==========================
                              if (o.sellerUsername != null &&
                                  o.sellerUsername!.isNotEmpty)
                                Text(
                                  'Penjual: ${o.sellerUsername!}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // ==========================
                              //   Info produk yang dibeli
                              // ==========================
                              FutureBuilder<Product>(
                                future: _getProduct(
                                  o.productId,
                                ), // pastikan OrderModel punya field productId
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text(
                                      'Memuat info produk...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }

                                  if (snap.hasError || !snap.hasData) {
                                    // fallback kalau gagal ambil produk
                                    return Text(
                                      'Produk #${o.productId}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    );
                                  }

                                  final p = snap.data!;
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // thumbnail
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 60,
                                          height: 60,
                                          child:
                                              (p.image != null &&
                                                  p.image!.isNotEmpty)
                                              ? Image.network(
                                                  p.image!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.image,
                                                  size: 32,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // nama + harga
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (p.offerPrice != null)
                                              Text('Rp ${p.offerPrice}')
                                            else if (p.price != null)
                                              Text('Rp ${p.price}'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              // ==========================
                              //   Info order (sebelumnya)
                              // ==========================
                              Text(
                                "Order #${o.id}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (o.totalPrice != null)
                                Text("Total: Rp ${o.totalPrice}"),
                              Text("Metode: ${o.paymentMethod.toUpperCase()}"),
                              Text("Status: ${o.status}"),

                              const SizedBox(height: 6),
                              const Text(
                                "Alamat Pengiriman:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),

                              if (o.shippingStreet != null &&
                                  o.shippingStreet!.isNotEmpty)
                                Text(o.shippingStreet!)
                              else
                                const Text('-'),

                              Text(
                                "${o.shippingCity ?? '-'}, ${o.shippingState ?? '-'}",
                              ),
                              Text(
                                "${o.shippingPostalCode ?? '-'}, ${o.shippingCountry ?? '-'}",
                              ),
                              if (o.shippingPhone != null &&
                                  o.shippingPhone!.isNotEmpty)
                                Text("Telp: ${o.shippingPhone}")
                              else
                                const Text("Telp: -"),

                              const SizedBox(height: 8),

                              // BARU UPDATE

                              // Tombol Batalkan Pesanan (hanya jika status pending)
                              if (o.status.toLowerCase() == 'pending')
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _cancelOrder(o.id),
                                    child: const Text(
                                      'Batalkan Pesanan',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),

                              // =====================
                              // Tombol "Pesanan selesai"
                              // =====================
                              if (o.status.toLowerCase() != 'selesai' &&
                                  o.status.toLowerCase() != 'cancelled')
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _markOrderAsCompleted(o.id),
                                    child: const Text('Pesanan selesai'),
                                  ),
                                ),

                              const Align(
                                alignment: Alignment.centerRight,
                                child: Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
