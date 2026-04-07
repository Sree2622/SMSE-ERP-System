import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, int> scannedQty = {};

  Future<void> _saveScannedStock(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (final doc in docs) {
      final qty = scannedQty[doc.id] ?? 0;
      if (qty <= 0) continue;
      final current = (doc.data()['stock'] ?? 0) as int;
      await doc.reference.update({'stock': current + qty, 'updatedAt': Timestamp.now()});
    }

    await FirestoreService.db.collection('scan_logs').add({
      'items': scannedQty.entries.where((e) => e.value > 0).map((e) => {'itemId': e.key, 'qty': e.value}).toList(),
      'createdAt': Timestamp.now(),
    });

    if (mounted) {
      setState(scannedQty.clear);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanned stock saved to Firebase')));
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
        title: const Text('Scan Stock', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.inventory.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return Column(
            children: [
              Container(
                height: 220,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                child: const Center(
                  child: Text('Camera/barcode integration can update scanned quantities',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Detected Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${scannedQty.values.where((v) => v > 0).length} items'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final qty = scannedQty[doc.id] ?? 0;

                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(data['name'] ?? 'Unnamed'),
                      subtitle: Text('Detected quantity: $qty'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: qty > 0 ? () => setState(() => scannedQty[doc.id] = qty - 1) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: () => setState(() => scannedQty[doc.id] = qty + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: docs.isEmpty ? null : () => _saveScannedStock(docs),
                    child: const Text('Confirm & Save'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
