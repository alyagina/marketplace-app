// lib/pages/product_form_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

class CreateEditProductPage extends StatefulWidget {
  final Product? product; // null = create, not null = edit

  const CreateEditProductPage({super.key, this.product});

  @override
  State<CreateEditProductPage> createState() => _CreateEditProductPageState();
}

class _CreateEditProductPageState extends State<CreateEditProductPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameC = TextEditingController();
  final TextEditingController _categoryC = TextEditingController();
  final TextEditingController _descriptionC = TextEditingController();
  final TextEditingController _priceC = TextEditingController();
  final TextEditingController _offerPriceC = TextEditingController();

  File? _imageFile;
  bool _isSubmitting = false;

  bool get isEdit => widget.product != null;

  int? _userId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserId();

    if (isEdit) {
      final p = widget.product!;
      _nameC.text = p.name;
      _categoryC.text = p.category ?? '';
      _descriptionC.text = p.description ?? '';
      _priceC.text = p.price?.toString() ?? '';
      _offerPriceC.text = p.offerPrice?.toString() ?? '';
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id');
      _isLoadingUser = false;
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    _categoryC.dispose();
    _descriptionC.dispose();
    _priceC.dispose();
    _offerPriceC.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isEdit && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih gambar produk')),
      );
      return;
    }

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User belum login, tidak bisa membuat produk'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (isEdit) {
        await _updateProduct();
      } else {
        await _createProduct();
      }

      if (!mounted) return;
      Navigator.pop(context, true); // kembali + tanda data berubah
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _createProduct() async {
    if (_userId == null) {
      throw Exception('User belum login / user_id tidak ditemukan');
    }

    final uri = Uri.parse('http://mortava.biz.id/api/products');
    final request = http.MultipartRequest('POST', uri);

    request.fields['name'] = _nameC.text.trim();
    request.fields['category'] = _categoryC.text.trim();
    request.fields['description'] = _descriptionC.text.trim();
    request.fields['price'] = _priceC.text.trim();
    request.fields['offer_price'] = _offerPriceC.text.trim();
    request.fields['user_id'] = _userId!
        .toString(); // <- ini sekarang pasti angka

    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', _imageFile!.path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      debugPrint('Create product response: $body');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produk berhasil dibuat')));
    } else {
      throw Exception('Gagal membuat produk (${response.statusCode})');
    }
  }

  Future<void> _updateProduct() async {
    final p = widget.product!;
    final uri = Uri.parse('http://mortava.biz.id/api/products/${p.id}');

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'name': _nameC.text.trim(),
        'price': int.tryParse(_priceC.text.trim()) ?? 0,
        'offer_price': int.tryParse(_offerPriceC.text.trim()) ?? 0,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body);
      debugPrint('Update product response: $body');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk berhasil diperbarui')),
      );
    } else {
      throw Exception('Gagal update produk (${response.statusCode})');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tunggu sampai user_id ke-load dulu
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Preview gambar (create saja yg bisa pilih)
              if (!isEdit) ...[
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          )
                        : const Center(child: Text('Pilih Gambar Produk')),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameC,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryC,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionC,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _offerPriceC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga Promo (offer_price)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Simpan Perubahan' : 'Buat Produk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
