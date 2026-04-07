import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<Map<String, dynamic>> _loadReports() async {
    final billsSnapshot = await FirestoreService.bills.orderBy('createdAt', descending: true).limit(20).get();
    final inventorySnapshot = await FirestoreService.inventory.get();

    final totalRevenue = billsSnapshot.docs.fold<double>(0, (sum, doc) {
      final total = doc.data()['total'] ?? 0;
      return sum + (total is int ? total.toDouble() : (total as double));
    });

    final totalOrders = billsSnapshot.docs.length;
    final lowStockCount = inventorySnapshot.docs.where((doc) => ((doc.data()['stock'] ?? 0) as int) <= 5).length;

    String topItem = 'N/A';
    final Map<String, int> soldCount = {};
    for (final bill in billsSnapshot.docs) {
      final items = (bill.data()['items'] ?? []) as List<dynamic>;
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final name = (item['name'] ?? 'Unknown').toString();
        final qty = (item['qty'] ?? 0) as int;
        soldCount[name] = (soldCount[name] ?? 0) + qty;
      }
    }
    if (soldCount.isNotEmpty) {
      topItem = soldCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'lowStockCount': lowStockCount,
      'topItem': topItem,
      'recentBills': billsSnapshot.docs,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Reports & Analytics', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final recentBills = data['recentBills'] as List<QueryDocumentSnapshot<Map<String, dynamic>>>? ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Color(0xff4e73df), Color(0xff224abe)]),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Recent Revenue", style: TextStyle(color: Colors.white70)),
                          Text('₹${(data['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Icon(Icons.trending_up, color: Colors.white, size: 40),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _tile('Total Orders', '${data['totalOrders'] ?? 0}', Icons.shopping_cart, Colors.orange),
                    _tile('Top Item', '${data['topItem'] ?? 'N/A'}', Icons.star, Colors.green),
                    _tile('Low Stock Items', '${data['lowStockCount'] ?? 0}', Icons.inventory, Colors.red),
                    _tile('Customers', '${data['totalOrders'] ?? 0}', Icons.people, Colors.purple),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Recent Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...recentBills.take(5).map((bill) {
                  final billData = bill.data();
                  final ts = billData['createdAt'] as Timestamp?;
                  final date = ts?.toDate();
                  return Card(
                    child: ListTile(
                      title: Text('Bill ${bill.id.substring(0, 6)}'),
                      subtitle: Text('${date ?? ''}'),
                      trailing: Text('₹${billData['total'] ?? 0}'),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
