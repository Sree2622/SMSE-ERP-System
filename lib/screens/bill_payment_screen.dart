import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class BillPaymentScreen extends StatelessWidget {
  const BillPaymentScreen({super.key});

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

  Future<String?> _showPaymentGateway(BuildContext context, int amount) async {
    var selectedMethod = 'UPI';
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pay Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: ₹$amount'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedMethod = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedMethod),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payBill(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final total = _asInt(doc.data()['total']);
    final method = await _showPaymentGateway(context, total);
    if (method == null) return;

    await doc.reference.update({
      'payment.status': 'paid',
      'payment.method': method,
      'payment.paidAt': Timestamp.now(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bill ${doc.id.substring(0, 8).toUpperCase()} paid')),
    );
  }

  Future<void> _viewBill(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> billDoc) async {
    final data = billDoc.data();
    final items =
        (data['items'] as List<dynamic>? ?? []).map((item) => item as Map).toList();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final total = _asInt(data['total']);
    final status = (data['payment']?['status'] ?? 'pending').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bill ${billDoc.id.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(_formatDateTime(createdAt)),
            const SizedBox(height: 8),
            Chip(
              label: Text(status.toUpperCase()),
              backgroundColor:
                  status == 'paid' ? Colors.green.shade100 : Colors.orange.shade100,
            ),
            const Divider(height: 22),
            ...items.map((item) {
              final qty = _asInt(item['qty']);
              final price = _asInt(item['price']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item['name']?.toString() ?? 'Item')),
                    Text('$qty x ₹$price'),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total: ₹$total',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        title: const Text('My Bills & Payment'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.bills
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No bills available.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final total = _asInt(data['total']);
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final payment =
                  Map<String, dynamic>.from(data['payment'] ?? const <String, dynamic>{});
              final status = (payment['status'] ?? 'pending').toString().toLowerCase();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text('Bill ${doc.id.substring(0, 8).toUpperCase()}'),
                  subtitle: Text(
                      '${_formatDateTime(createdAt)}\nTotal: ₹$total\nStatus: ${status.toUpperCase()}'),
                  isThreeLine: true,
                  onTap: () => _viewBill(context, doc),
                  trailing: status == 'paid'
                      ? const Chip(label: Text('Paid'))
                      : FilledButton(
                          onPressed: () => _payBill(context, doc),
                          child: const Text('Pay'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
