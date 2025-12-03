import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

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

  Future<void> _loadUserAndOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (!mounted) return;

    if (userId == null) {
      // kalau belum login / user_id hilang
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
        return body.map((e) => OrderModel.fromJson(e)).toList();
      } else {
        throw Exception("Format API tidak sesuai (harus list)");
      }
    } else {
      throw Exception("Gagal memuat pesanan (${response.statusCode})");
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(
                          "Order #${o.id}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text("Total: Rp ${o.totalPrice}"),
                            Text("Metode: ${o.paymentMethod.toUpperCase()}"),
                            Text("Status: ${o.status}"),
                            const SizedBox(height: 6),
                            const Text(
                              "Alamat Pengiriman:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(o.shippingStreet),
                            Text("${o.shippingCity}, ${o.shippingState}"),
                            Text(
                              "${o.shippingPostalCode}, ${o.shippingCountry}",
                            ),
                            Text("Telp: ${o.shippingPhone}"),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: detail order
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
