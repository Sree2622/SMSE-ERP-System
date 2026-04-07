import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String searchText = '';

  Color getStockColor(int stock) {
    if (stock <= 5) return Colors.red;
    if (stock <= 15) return Colors.orange;
    return Colors.green;
  }

  String getStockLabel(int stock) {
    if (stock <= 5) return 'Low Stock';
    if (stock <= 15) return 'Medium';
    return 'In Stock';
  }

  Future<void> _showItemDialog({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final nameController = TextEditingController(text: doc?.data()?['name'] ?? '');
    final stockController = TextEditingController(text: (doc?.data()?['stock'] ?? '').toString());
    final priceController = TextEditingController(text: (doc?.data()?['price'] ?? '').toString());

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? 'Add Item' : 'Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock')),
            TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final data = {
                'name': nameController.text.trim(),
                'stock': int.tryParse(stockController.text.trim()) ?? 0,
                'price': int.tryParse(priceController.text.trim()) ?? 0,
                'updatedAt': Timestamp.now(),
              };

              if (doc == null) {
                await FirestoreService.inventory.add({...data, 'createdAt': Timestamp.now()});
              } else {
                await doc.reference.update(data);
              }

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
        title: const Text('Inventory', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4e73df),
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => searchText = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search item...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.inventory.orderBy('updatedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No inventory items. Add your first item.'));
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final name = (doc.data()['name'] ?? '').toString().toLowerCase();
                  return name.contains(searchText);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final stock = (data['stock'] ?? 0) as int;
                    final price = (data['price'] ?? 0) as int;

                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('$stock units • ₹$price'),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            label: Text(getStockLabel(stock), style: TextStyle(color: getStockColor(stock))),
                            backgroundColor: getStockColor(stock).withOpacity(0.15),
                          ),
                          IconButton(onPressed: () => _showItemDialog(doc: doc), icon: const Icon(Icons.edit)),
                          IconButton(
                            onPressed: () => doc.reference.delete(),
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
