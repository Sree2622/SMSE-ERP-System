import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'billing_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final String role;

  const HomeScreen({super.key, this.role = 'vendor'});

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final revenue = await FirestoreService.fetchTodayRevenue();
    final lowStock = await FirestoreService.inventory
        .where('stock', isLessThanOrEqualTo: 5)
        .get();

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
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, color: Colors.black54),
          ),
        ],
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xff4e73df).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront,
                  color: Color(0xff4e73df), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart Kirana',
              style: TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(role == 'vendor' ? 'Vendor Dashboard' : 'Dashboard',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                Text(
                  _todayLabel(),
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 15),
            FutureBuilder<Map<String, dynamic>>(
              future: _loadDashboardData(),
              builder: (context, snapshot) {
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;
                final revenue =
                    snapshot.data?['revenue'] as double? ?? 0;
                final lowStockCount =
                    snapshot.data?['lowStockCount'] as int? ?? 0;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                        colors: [Color(0xff4e73df), Color(0xff224abe)]),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff4e73df).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Today's Sales",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            isLoading
                                ? Container(
                                    height: 30,
                                    width: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                  )
                                : Text(
                                    '₹${revenue.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold),
                                  ),
                            const SizedBox(height: 6),
                            if (!isLoading)
                              Row(
                                children: [
                                  Icon(
                                    lowStockCount > 0
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    size: 13,
                                    color: lowStockCount > 0
                                        ? Colors.orange.shade300
                                        : Colors.green.shade300,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    lowStockCount > 0
                                        ? '$lowStockCount low stock item(s)'
                                        : 'All items well stocked',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (isLoading)
                        const CircularProgressIndicator(
                            color: Colors.white)
                      else
                        const Icon(Icons.trending_up,
                            color: Colors.white, size: 40),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            const Text('Quick Actions',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: role == 'vendor'
                    ? const [
                        _DashboardTile(
                            icon: Icons.camera_alt,
                            label: 'Scan Stock',
                            color: Colors.orange,
                            page: ScanScreen()),
                        _DashboardTile(
                            icon: Icons.receipt_long,
                            label: 'New Bill',
                            color: Colors.green,
                            page: BillingScreen()),
                        _DashboardTile(
                            icon: Icons.inventory,
                            label: 'Inventory',
                            color: Colors.blue,
                            page: InventoryScreen()),
                        _DashboardTile(
                            icon: Icons.bar_chart,
                            label: 'Reports',
                            color: Colors.purple,
                            page: ReportsScreen()),
                        _DashboardTile(
                            icon: Icons.settings,
                            label: 'Settings',
                            color: Colors.grey,
                            page: SettingsScreen()),
                      ]
                    : const [],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget page;

  const _DashboardTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.page});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
