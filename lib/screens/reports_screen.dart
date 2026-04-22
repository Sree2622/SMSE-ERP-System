import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<Map<String, dynamic>> _loadReports() async {
    final billsSnapshot = await FirestoreService.bills
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    final inventorySnapshot = await FirestoreService.inventory.get();

    final totalRevenue = billsSnapshot.docs.fold<double>(0, (sum, doc) {
      final total = doc.data()['total'] ?? 0;
      return sum + (total is int ? total.toDouble() : (total as double));
    });

    final totalOrders = billsSnapshot.docs.length;
    final lowStockCount = inventorySnapshot.docs
        .where((doc) => ((doc.data()['stock'] ?? 0) as int) <= 5)
        .length;
    final totalInventoryItems = inventorySnapshot.docs.length;

    String topItem = 'N/A';
    final Map<String, int> soldCount = {};
    for (final bill in billsSnapshot.docs) {
      final items =
          (bill.data()['items'] ?? []) as List<dynamic>;
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final name = (item['name'] ?? 'Unknown').toString();
        final qty = (item['qty'] ?? 0) as int;
        soldCount[name] = (soldCount[name] ?? 0) + qty;
      }
    }
    if (soldCount.isNotEmpty) {
      topItem = soldCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'lowStockCount': lowStockCount,
      'topItem': topItem,
      'totalInventoryItems': totalInventoryItems,
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
        title: const Text('Reports & Analytics',
            style: TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Unable to load reports.'),
                  const SizedBox(height: 4),
                  Text('Check your connection and try again.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};
          final recentBills = data['recentBills']
                  as List<QueryDocumentSnapshot<Map<String, dynamic>>>? ??
              [];

          return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // REVENUE CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                          colors: [Color(0xff4e73df), Color(0xff224abe)]),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xff4e73df).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Recent Revenue (last 20 bills)',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              '₹${(data['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['totalOrders'] ?? 0} orders recorded',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        const Icon(Icons.trending_up,
                            color: Colors.white, size: 44),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // STATS GRID
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.4,
                    children: [
                      _statTile(
                        'Total Orders',
                        '${data['totalOrders'] ?? 0}',
                        Icons.shopping_cart_outlined,
                        Colors.orange,
                      ),
                      _statTile(
                        'Top Selling',
                        '${data['topItem'] ?? 'N/A'}',
                        Icons.star_outline,
                        Colors.green,
                        overflow: true,
                      ),
                      _statTile(
                        'Low Stock Items',
                        '${data['lowStockCount'] ?? 0}',
                        Icons.warning_amber_outlined,
                        (data['lowStockCount'] ?? 0) > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                      _statTile(
                        'Total SKUs',
                        '${data['totalInventoryItems'] ?? 0}',
                        Icons.inventory_2_outlined,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // RECENT BILLS
                  const Text('Recent Bills',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (recentBills.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No bills generated yet.'),
                          ],
                        ),
                      ),
                    )
                  else
                    ...recentBills.take(10).map((bill) {
                      final billData = bill.data();
                      final ts =
                          billData['createdAt'] as Timestamp?;
                      final date = ts?.toDate();
                      final total = billData['total'] ?? 0;
                      final itemCount =
                          billData['itemCount'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xff4e73df)
                                .withOpacity(0.1),
                            child: const Icon(
                                Icons.receipt_outlined,
                                color: Color(0xff4e73df)),
                          ),
                          title: Text(
                            'Bill ${bill.id.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            date != null
                                ? _formatDate(date)
                                : 'Unknown date',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹$total',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                              Text(
                                '$itemCount items',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                ],
              ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }

  Widget _statTile(String title, String value, IconData icon, Color color,
      {bool overflow = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            overflow: overflow ? TextOverflow.ellipsis : null,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }
}
