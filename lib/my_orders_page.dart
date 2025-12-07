import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';
import '../models/product_model.dart';
import 'order_detail_page.dart';

Widget statusBadge(String s) {
  final status = s.toLowerCase().trim();

  late Color bg, textColor;
  late String label;

  switch (status) {
    case 'pending':
      label = 'Menunggu';
      bg = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
      break;

    case 'dikirim':
      label = 'Dikirim';
      bg = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
      break;

    case 'success':
      label = 'Selesai';
      bg = Colors.green.shade100;
      textColor = Colors.green.shade800;
      break;

    case 'cancelled':
      label = 'Dibatalkan';
      bg = Colors.red.shade100;
      textColor = Colors.red.shade800;
      break;

    default:
      label = s;
      bg = Colors.grey.shade200;
      textColor = Colors.grey.shade600;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}

Widget smallButton({
  required String label,
  required VoidCallback onPressed,
  Color color = Colors.blue,
}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

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
                              // Penjual
                              if (o.sellerUsername != null &&
                                  o.sellerUsername!.isNotEmpty)
                                Text(
                                  'Penjual: ${o.sellerUsername!}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Produk
                              FutureBuilder<Product>(
                                future: _getProduct(o.productId),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text("Memuat produk...");
                                  }

                                  if (snap.hasError || !snap.hasData) {
                                    return Text(
                                      "Produk #${o.productId}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }

                                  final p = snap.data!;

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 65,
                                          height: 65,
                                          child:
                                              p.image != null &&
                                                  p.image!.isNotEmpty
                                              ? Image.network(
                                                  p.image!,
                                                  fit: BoxFit.cover,
                                                )
                                              : const Icon(
                                                  Icons.image,
                                                  size: 32,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

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
                                            Text(
                                              p.offerPrice != null
                                                  ? "Rp ${p.offerPrice}"
                                                  : "Rp ${p.price}",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              // Order Info + Status Badge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Order #${o.id}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  statusBadge(o.status),
                                ],
                              ),

                              const SizedBox(height: 8),

                              if (o.totalPrice != null)
                                Text("Total: Rp ${o.totalPrice}"),
                              Text("Metode: ${o.paymentMethod.toUpperCase()}"),

                              const SizedBox(height: 10),

                              // Tombol Aksi Pembeli (Pending / Dikirim)
                              Builder(
                                builder: (context) {
                                  final status = o.status.toLowerCase();

                                  if (status == "pending") {
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: smallButton(
                                        label: "Batalkan Pesanan",
                                        color: Colors.red,
                                        onPressed: () => _cancelOrder(o.id),
                                      ),
                                    );
                                  }

                                  if (status == "dikirim") {
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: smallButton(
                                        label: "Pesanan selesai",
                                        color: Colors.green,
                                        onPressed: () =>
                                            _markOrderAsCompleted(o.id),
                                      ),
                                    );
                                  }

                                  return const SizedBox.shrink();
                                },
                              ),

                              const SizedBox(height: 10),

                              // Arrow icon
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
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
