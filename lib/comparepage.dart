import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  Map<String, dynamic>? _product1;
  Map<String, dynamic>? _product2;
  bool _loading1 = false;
  bool _loading2 = false;

  Future<Map<String, dynamic>?> _fetchProduct(String barcode) async {
    final url =
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 1) return data['product'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _scan(int slot) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
          builder: (_) => const SimpleBarcodeScannerPage()),
    );
    if (result == null || result == '-1' || result.isEmpty) return;

    setState(() {
      if (slot == 1) _loading1 = true;
      if (slot == 2) _loading2 = true;
    });

    final product = await _fetchProduct(result);

    setState(() {
      if (slot == 1) {
        _product1 = product;
        _loading1 = false;
      } else {
        _product2 = product;
        _loading2 = false;
      }
    });

    if (product == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found in database')),
      );
    }
  }

  String _nutriScore(Map<String, dynamic> product) {
    final n = product['nutriscore_grade'];
    if (n != null) return n.toString().toUpperCase();
    final nutriments = product['nutriments'] ?? {};
    final sugar = (nutriments['sugars'] ?? 0).toDouble();
    final fats = (nutriments['fat'] ?? 0).toDouble();
    final proteins = (nutriments['proteins'] ?? 0).toDouble();
    if (sugar > 10 || fats > 20) return 'C';
    if (sugar > 5 || fats > 10) return 'B';
    if (proteins >= 2) return 'A';
    return 'B';
  }

  Color _scoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return Colors.green[700]!;
      case 'B': return Colors.lightGreen[600]!;
      case 'C': return Colors.orange[700]!;
      case 'D': return Colors.deepOrange[600]!;
      default: return Colors.red[700]!;
    }
  }

  Widget _buildSlot(int slot, Map<String, dynamic>? product, bool loading) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : () => _scan(slot),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: loading
                ? const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()))
                : product == null
                    ? SizedBox(
                        height: 160,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline,
                                size: 44,
                                color: Colors.green[300]),
                            const SizedBox(height: 10),
                            Text(
                              'Tap to scan\nProduct ${slot}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _buildProductCard(product),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['product_name'] ?? 'Unknown';
    final nutriments = product['nutriments'] ?? {};
    final sugar = (nutriments['sugars'] ?? 0).toDouble();
    final proteins = (nutriments['proteins'] ?? 0).toDouble();
    final fats = (nutriments['fat'] ?? 0).toDouble();
    final sodium = (nutriments['sodium'] ?? 0).toDouble();
    final score = _nutriScore(product);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _scoreColor(score),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                score,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const Divider(height: 20),
        _row('Protein', '${proteins.toStringAsFixed(1)}g'),
        _row('Fats', '${fats.toStringAsFixed(1)}g'),
        _row('Sugar', '${sugar.toStringAsFixed(1)}g'),
        _row('Sodium', '${sodium.toStringAsFixed(2)}g'),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVerdictBanner() {
    if (_product1 == null || _product2 == null) return const SizedBox.shrink();
    final s1 = _nutriScore(_product1!);
    final s2 = _nutriScore(_product2!);
    final scores = ['A', 'B', 'C', 'D', 'E'];
    final i1 = scores.indexOf(s1);
    final i2 = scores.indexOf(s2);
    final name1 = _product1!['product_name'] ?? 'Product 1';
    final name2 = _product2!['product_name'] ?? 'Product 2';

    String verdict;
    Color color;
    if (i1 < i2) {
      verdict = '✓  $name1 is the healthier choice (NutriScore $s1 vs $s2)';
      color = Colors.green[700]!;
    } else if (i2 < i1) {
      verdict = '✓  $name2 is the healthier choice (NutriScore $s2 vs $s1)';
      color = Colors.green[700]!;
    } else {
      verdict = 'Both products have the same NutriScore ($s1)';
      color = Colors.orange[700]!;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        verdict,
        style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.lightGreen[200],
        title: const Text('Scan & Compare',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Scan two products to compare their nutrition',
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSlot(1, _product1, _loading1),
                const SizedBox(width: 10),
                _buildSlot(2, _product2, _loading2),
              ],
            ),
            _buildVerdictBanner(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}