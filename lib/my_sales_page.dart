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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

class MySalesPage extends StatefulWidget {
  const MySalesPage({super.key});

  @override
  State<MySalesPage> createState() => _MySalesPageState();
}

class _MySalesPageState extends State<MySalesPage> {
  Future<List<OrderModel>>? _futureSales;
  int? _userId;

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

  @override
  void initState() {
    super.initState();
    _loadUserAndSales();
  }

  Future<void> _loadUserAndSales() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');

    if (!mounted) return;

    if (id == null) {
      setState(() {
        _futureSales = Future.error('User belum login');
      });
      return;
    }

    setState(() {
      _userId = id;
      _futureSales = _fetchSales();
    });
  }

  Future<List<OrderModel>> _fetchSales() async {
    if (_userId == null) {
      throw Exception('User belum login');
    }

    final url = Uri.parse('http://mortava.biz.id/api/orders/sell/$_userId');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body is List) {
        return body
            .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Format API tidak sesuai (harus List)');
      }
    } else {
      throw Exception('Gagal memuat penjualan (${response.statusCode})');
    }
  }

  Future<void> _markOrderAsShipped(int orderId) async {
    final url = Uri.parse('http://mortava.biz.id/api/orders/$orderId/ship');

    final response = await http.patch(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _futureSales = _fetchSales();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pesanan ditandai dikirim')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesanan: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan Saya')),
      body: _futureSales == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<OrderModel>>(
              future: _futureSales,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final sales = snapshot.data ?? [];

                if (sales.isEmpty) {
                  return const Center(child: Text('Belum ada penjualan'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final o = sales[index];

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
                              // Username Pembeli
                              if (o.buyerUsername != null &&
                                  o.buyerUsername!.isNotEmpty)
                                Text(
                                  'Pembeli: ${o.buyerUsername!}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Produk Thumbnail + Info
                              FutureBuilder<Product>(
                                future: _getProduct(o.productId),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text(
                                      "Memuat info produk...",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }

                                  if (snap.hasError || !snap.hasData) {
                                    return Text(
                                      "Produk #${o.productId}",
                                      style: const TextStyle(
                                        fontSize: 16,
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
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
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

                              // Order info header + status badge
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
                                Text('Total: Rp ${o.totalPrice}'),
                              Text('Metode: ${o.paymentMethod.toUpperCase()}'),

                              const SizedBox(height: 10),

                              // Tombol "Pesanan dikirim" untuk penjual
                              if (o.status.toLowerCase() == 'pending')
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: smallButton(
                                    label: "Pesanan dikirim",
                                    color: Colors.blue,
                                    onPressed: () => _markOrderAsShipped(o.id),
                                  ),
                                ),

                              const SizedBox(height: 8),

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
