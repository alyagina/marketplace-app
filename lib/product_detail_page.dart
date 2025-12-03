// lib/pages/product_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/product_model.dart';

class ProductDetailPage extends StatefulWidget {
  final int productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<Product> _futureProduct;

  Future<Product> _fetchProductDetail() async {
    final url = Uri.parse(
      'http://mortava.biz.id/api/products/${widget.productId}',
    );
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      // Antisipasi:
      // 1) langsung object
      // 2) { "data": {...} }
      // 3) { "product": {...} }
      Map<String, dynamic> map;
      if (body is Map && body['data'] is Map) {
        map = Map<String, dynamic>.from(body['data']);
      } else if (body is Map && body['product'] is Map) {
        map = Map<String, dynamic>.from(body['product']);
      } else if (body is Map) {
        map = Map<String, dynamic>.from(body);
      } else {
        throw Exception('Format detail produk tidak dikenali');
      }

      return Product.fromJson(map);
    } else {
      throw Exception('Gagal memuat detail produk (${response.statusCode})');
    }
  }

  @override
  void initState() {
    super.initState();
    _futureProduct = _fetchProductDetail();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: FutureBuilder<Product>(
        future: _futureProduct,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final p = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.image != null && p.image!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      p.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported),
                    ),
                  )
                else
                  const SizedBox(
                    height: 200,
                    child: Center(child: Icon(Icons.image, size: 50)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (p.category != null)
                        Text(
                          p.category!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 8),
                      if (p.offerPrice != null)
                        Row(
                          children: [
                            if (p.price != null)
                              Text(
                                'Rp ${p.price}',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              'Rp ${p.offerPrice}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else if (p.price != null)
                        Text(
                          'Rp ${p.price}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (p.quantity != null) Text('Stok: ${p.quantity}'),
                      const SizedBox(height: 16),
                      const Text(
                        'Deskripsi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.description?.isNotEmpty == true
                            ? p.description!
                            : 'Tidak ada deskripsi',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: aksi beli / tambah ke keranjang
                          },
                          child: const Text('Beli Sekarang'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
