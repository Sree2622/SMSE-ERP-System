import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _editShopDetails(Map<String, dynamic> data) async {
    final nameController = TextEditingController(text: data['storeName'] ?? '');
    final gstController = TextEditingController(text: data['gst'] ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shop Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Store Name')),
            TextField(controller: gstController, decoration: const InputDecoration(labelText: 'GST Number')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await FirestoreService.shopProfile.set({
                'storeName': nameController.text.trim(),
                'gst': gstController.text.trim(),
                'updatedAt': Timestamp.now(),
              }, SetOptions(merge: true));
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
        title: const Text('Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.shopProfile.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ??
              {
                'storeName': 'Set store name',
                'gst': 'Set GST number',
                'darkMode': false,
              };

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [Color(0xff4e73df), Color(0xff224abe)]),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.store, color: Colors.white)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['storeName'] ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('GST: ${data['gst'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.edit),
                title: const Text('Edit Shop Details'),
                onTap: () => _editShopDetails(data),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: (data['darkMode'] ?? false) as bool,
                onChanged: (value) => FirestoreService.shopProfile.set({'darkMode': value}, SetOptions(merge: true)),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
              ),
            ],
          );
        },
      ),
    );
  }
}
