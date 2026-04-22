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
    bool isSaving = false;
    final nameController =
        TextEditingController(text: data['storeName'] ?? '');
    final gstController =
        TextEditingController(text: data['gst'] ?? '');
    final phoneController =
        TextEditingController(text: data['phone'] ?? '');
    final addressController =
        TextEditingController(text: data['address'] ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.store, color: Color(0xff4e73df)),
              SizedBox(width: 8),
              Text('Edit Shop Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _inputField(nameController, 'Store Name',
                    Icons.storefront_outlined),
                const SizedBox(height: 12),
                _inputField(
                    gstController, 'GST Number', Icons.receipt_outlined),
                const SizedBox(height: 12),
                _inputField(phoneController, 'Phone Number',
                    Icons.phone_outlined,
                    inputType: TextInputType.phone),
                const SizedBox(height: 12),
                _inputField(addressController, 'Address',
                    Icons.location_on_outlined,
                    maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton.icon(
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      await FirestoreService.shopProfile.set({
                        'storeName': nameController.text.trim(),
                        'gst': gstController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'address': addressController.text.trim(),
                        'updatedAt': Timestamp.now(),
                      }, SetOptions(merge: true));
                      setDialogState(() => isSaving = false);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shop details saved.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
        title: const Text('Settings',
            style: TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.shopProfile.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ??
              {
                'storeName': 'Set store name',
                'gst': 'Set GST number',
                'phone': '',
                'address': '',
                'darkMode': false,
              };

          final storeName =
              (data['storeName'] ?? 'Set store name').toString();
          final gst = (data['gst'] ?? 'Set GST number').toString();
          final phone = (data['phone'] ?? '').toString();
          final address = (data['address'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // SHOP PROFILE CARD
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
                  children: [
                    const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.store,
                            color: Colors.white, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(storeName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          const SizedBox(height: 2),
                          Text('GST: $gst',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                          if (phone.isNotEmpty)
                            Text('📞 $phone',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                          if (address.isNotEmpty)
                            Text('📍 $address',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SECTION LABEL
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('Store Settings',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ),

              // EDIT SHOP DETAILS
              _settingsTile(
                icon: Icons.edit_outlined,
                title: 'Edit Shop Details',
                subtitle:
                    'Update store name, GST, phone & address',
                onTap: () => _editShopDetails(data),
              ),
              const SizedBox(height: 8),

              // DARK MODE
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  value: (data['darkMode'] ?? false) as bool,
                  onChanged: (value) =>
                      FirestoreService.shopProfile.set(
                          {'darkMode': value}, SetOptions(merge: true)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dark_mode_outlined,
                        color: Colors.grey),
                  ),
                  title: const Text('Dark Mode',
                      style:
                          TextStyle(fontWeight: FontWeight.w600)),
                  subtitle:
                      const Text('Toggle app appearance'),
                ),
              ),
              const SizedBox(height: 20),

              // ABOUT SECTION
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('About',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ),

              _settingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: null,
                trailing: const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xff4e73df).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, color: const Color(0xff4e73df), size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: Colors.grey.shade500, fontSize: 12)),
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
