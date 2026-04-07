import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'billing_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final revenue = await FirestoreService.fetchTodayRevenue();
    final lowStock = await FirestoreService.inventory.where('stock', isLessThanOrEqualTo: 5).get();

    return {
      'revenue': revenue,
      'lowStockCount': lowStock.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Smart Kirana',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            FutureBuilder<Map<String, dynamic>>(
              future: _loadDashboardData(),
              builder: (context, snapshot) {
                final revenue = snapshot.data?['revenue'] as double? ?? 0;
                final lowStockCount = snapshot.data?['lowStockCount'] as int? ?? 0;
                return Container(
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
                          const Text("Today's Sales", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text('₹${revenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Low stock items: $lowStockCount',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const CircularProgressIndicator(color: Colors.white)
                      else
                        const Icon(Icons.trending_up, color: Colors.white, size: 40),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: const [
                  _DashboardTile(icon: Icons.camera_alt, label: 'Scan Stock', color: Colors.orange, page: ScanScreen()),
                  _DashboardTile(icon: Icons.receipt_long, label: 'New Bill', color: Colors.green, page: BillingScreen()),
                  _DashboardTile(icon: Icons.inventory, label: 'Inventory', color: Colors.blue, page: InventoryScreen()),
                  _DashboardTile(icon: Icons.bar_chart, label: 'Reports', color: Colors.purple, page: ReportsScreen()),
                  _DashboardTile(icon: Icons.settings, label: 'Settings', color: Colors.grey, page: SettingsScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget page;

  const _DashboardTile({required this.icon, required this.label, required this.color, required this.page});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.15), child: Icon(icon, size: 28, color: color)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
