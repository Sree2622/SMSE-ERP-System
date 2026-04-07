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
  final Map<String, int> cart = {};

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    _initializeControllerFuture = _controller!.initialize();
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
      final price = (doc.data()['price'] ?? 0) as int;
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
      final stock = (data['stock'] ?? 0) as int;
      if (qty > stock) continue;

      items.add({
        'itemId': doc.id,
        'name': data['name'],
        'qty': qty,
        'price': data['price'] ?? 0,
      });

      await doc.reference.update({'stock': stock - qty, 'updatedAt': Timestamp.now()});
    }

    if (items.isEmpty) return;

    await FirestoreService.bills.add({
      'items': items,
      'itemCount': items.fold<int>(0, (sum, item) => sum + (item['qty'] as int)),
      'total': items.fold<int>(0, (sum, item) => sum + (item['qty'] as int) * (item['price'] as int)),
      'createdAt': Timestamp.now(),
    });

    if (mounted) {
      setState(cart.clear);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill generated and saved')));
    }
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
                  child: _controller == null
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
                    final stock = (data['stock'] ?? 0) as int;
                    final price = (data['price'] ?? 0) as int;
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
                            onPressed: qty > 0
                                ? () => setState(() => cart[doc.id] = qty - 1)
                                : null,
                          ),
                          Text('$qty'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: qty < stock
                                ? () => setState(() => cart[doc.id] = qty + 1)
                                : null,
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
