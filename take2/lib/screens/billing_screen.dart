import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _cameraError;
  final Map<String, int> cart = {};

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatDateTime(DateTime value) {
    return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year} '
        '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _cameraError = 'No camera found on this device';
        if (mounted) setState(() {});
        return;
      }

      _controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
    } catch (_) {
      _cameraError = 'Camera could not be started';
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _total(List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs) {
    var sum = 0;
    for (final doc in inventoryDocs) {
      final qty = cart[doc.id] ?? 0;
      final price = _asInt(doc.data()['price']);
      sum += qty * price;
    }
    return sum;
  }

  Future<void> _generateBill(List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs) async {
    final items = <Map<String, dynamic>>[];
    for (final doc in inventoryDocs) {
      final qty = cart[doc.id] ?? 0;
      if (qty <= 0) continue;
      final data = doc.data();
      final stock = _asInt(data['stock']);
      if (qty > stock) continue;

      final price = _asInt(data['price']);

      items.add({
        'itemId': doc.id,
        'name': data['name'],
        'qty': qty,
        'price': price,
      });

      await doc.reference.update({'stock': stock - qty, 'updatedAt': Timestamp.now()});
    }

    if (items.isEmpty) return;

    final createdAt = Timestamp.now();
    final itemCount = items.fold<int>(0, (sum, item) => sum + _asInt(item['qty']));
    final total = items.fold<int>(0, (sum, item) => sum + _asInt(item['qty']) * _asInt(item['price']));

    final billRef = await FirestoreService.bills.add({
      'items': items,
      'itemCount': itemCount,
      'total': total,
      'createdAt': createdAt,
    });

    if (mounted) {
      setState(cart.clear);
      _showBillPreview(
        billNumber: billRef.id.substring(0, 8).toUpperCase(),
        createdAt: createdAt.toDate(),
        itemCount: itemCount,
        total: total,
        items: items,
      );
    }
  }

  Future<void> _showBillPreview({
    required String billNumber,
    required DateTime createdAt,
    required int itemCount,
    required int total,
    required List<Map<String, dynamic>> items,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  const Center(
                    child: Text(
                      'Invoice / Bill',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Bill No: $billNumber'),
                  Text('Date: ${_formatDateTime(createdAt)}'),
                  const Divider(height: 30),
                  ...items.map((item) {
                    final qty = _asInt(item['qty']);
                    final price = _asInt(item['price']);
                    final amount = qty * price;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['name']?.toString() ?? 'Unnamed Item',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('$qty x ₹$price'),
                          const SizedBox(width: 12),
                          Text(
                            '₹$amount',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Items'),
                      Text('$itemCount'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹$total',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('New Bill', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.inventory.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final total = _total(docs);

          return Column(
            children: [
              Container(
                height: 220,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _cameraError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _cameraError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      : _controller == null
                          ? const Center(child: CircularProgressIndicator())
                          : FutureBuilder(
                              future: _initializeControllerFuture,
                              builder: (context, cameraSnapshot) {
                                if (cameraSnapshot.connectionState == ConnectionState.done) {
                                  return CameraPreview(_controller!);
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final stock = _asInt(data['stock']);
                    final price = _asInt(data['price']);
                    final qty = cart[doc.id] ?? 0;

                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(data['name'] ?? 'Unnamed'),
                      subtitle: Text('₹$price • Stock: $stock'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 0 ? () => setState(() => cart[doc.id] = qty - 1) : null,
                          ),
                          Text('$qty'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: qty < stock ? () => setState(() => cart[doc.id] = qty + 1) : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount'),
                        Text('₹$total',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff4e73df))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: docs.isEmpty ? null : () => _generateBill(docs),
                        child: const Text('Generate Bill'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
