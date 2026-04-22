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
  String stockFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _showItemDialog(
      {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final nameController =
        TextEditingController(text: doc?.data()?['name'] ?? '');
    final stockController =
        TextEditingController(text: (doc?.data()?['stock'] ?? '').toString());
    final priceController =
        TextEditingController(text: (doc?.data()?['price'] ?? '').toString());

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(doc == null ? Icons.add_box : Icons.edit,
                color: const Color(0xff4e73df)),
            const SizedBox(width: 8),
            Text(doc == null ? 'Add Item' : 'Edit Item'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Item Name',
                prefixIcon: const Icon(Icons.label_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stock (units)',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Price (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final name = nameController.text.trim();
              final stock = int.tryParse(stockController.text.trim()) ?? -1;
              final price = int.tryParse(priceController.text.trim()) ?? -1;

              if (name.isEmpty || stock < 0 || price < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Please enter a valid name, stock ≥ 0, and price ≥ 0.'),
                  ),
                );
                return;
              }

              final data = {
                'name': name,
                'stock': stock,
                'price': price,
                'updatedAt': Timestamp.now(),
              };

              if (doc == null) {
                await FirestoreService.inventory
                    .add({...data, 'createdAt': Timestamp.now()});
              } else {
                await doc.reference.update(data);
              }

              if (mounted) Navigator.pop(context);
            },
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(int stock) {
    switch (stockFilter) {
      case 'low':
        return stock <= 5;
      case 'medium':
        return stock > 5 && stock <= 15;
      case 'high':
        return stock > 15;
      default:
        return true;
    }
  }

  Future<void> _confirmDelete(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final name = doc.data()?['name']?.toString() ?? 'this item';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Item'),
          ],
        ),
        content: Text.rich(
          TextSpan(
            text: 'Are you sure you want to permanently delete ',
            children: [
              TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deletedData = doc.data();
      await doc.reference.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name deleted'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                // Restore the deleted document
                if (deletedData != null) {
                  await FirestoreService.inventory.add(deletedData);
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Inventory',
            style:
                TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xff4e73df),
        onPressed: () => _showItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => searchText = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search items…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchText = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          // FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('All', 'all', Icons.all_inclusive),
                _filterChip('Low Stock', 'low', Icons.warning_amber,
                    color: Colors.red),
                _filterChip('Medium', 'medium', Icons.remove,
                    color: Colors.orange),
                _filterChip('In Stock', 'high', Icons.check_circle_outline,
                    color: Colors.green),
              ],
            ),
          ),

          // INVENTORY LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.inventory
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Unable to load inventory.',
                            style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text('Check your connection and try again.',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No inventory items yet.',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Tap "Add Item" to add your first product.',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final name =
                      (doc.data()['name'] ?? '').toString().toLowerCase();
                  final stock = (doc.data()['stock'] ?? 0) as int;
                  return name.contains(searchText) && _matchesFilter(stock);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No items match your filters.'),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              searchText = '';
                              stockFilter = 'all';
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final stock = (data['stock'] ?? 0) as int;
                    final price = (data['price'] ?? 0) as int;
                    final stockColor = getStockColor(stock);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                        border: stock <= 5
                            ? Border.all(
                                color: Colors.red.shade200, width: 1)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: stockColor.withOpacity(0.15),
                          child: Icon(Icons.inventory_2,
                              color: stockColor, size: 20),
                        ),
                        title: Text(data['name'] ?? 'Unnamed',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Row(
                          children: [
                            Text('$stock units • ₹$price',
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: stockColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                getStockLabel(stock),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: stockColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showItemDialog(doc: doc),
                              icon: const Icon(Icons.edit_outlined,
                                  color: Color(0xff4e73df)),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              onPressed: () => _confirmDelete(doc),
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
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

  Widget _filterChip(String label, String value, IconData icon,
      {Color color = const Color(0xff4e73df)}) {
    final isSelected = stockFilter == value;
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87, fontSize: 13),
      onSelected: (_) => setState(() => stockFilter = value),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    );
  }
}
