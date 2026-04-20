import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/kirana_detection.dart';
import '../services/firestore_service.dart';
import '../services/kirana_vision_agent.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _cameraError;
  final Map<String, int> cart = {};
  String? _selectedHistoryBillId;
  String _searchText = '';
  bool _isAnalyzingImage = false;
  String? _billingScanMessage;
  final KiranaVisionAgent _visionAgent = KiranaVisionAgent();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

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

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _cameraError = 'No camera found on this device';
        if (mounted) setState(() {});
        return;
      }

      _controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
    } catch (_) {
      _cameraError = 'Camera could not be started';
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _total(List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs) {
    var sum = 0;
    for (final doc in inventoryDocs) {
      final qty = cart[doc.id] ?? 0;
      final price = _asInt(doc.data()['price']);
      sum += qty * price;
    }
    return sum;
  }

  Future<void> _analyzeBillFrame(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_isAnalyzingImage || _controller == null || !(_controller!.value.isInitialized)) return;

    try {
      final image = await _controller!.takePicture();
      await _analyzeBillImagePath(
        image.path,
        docs,
        emptyMessage: 'No known item detected. Keep product name text visible and retry.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _billingScanMessage = 'Frame analysis failed. Please retry.');
    }
  }

  Future<void> _analyzeUploadedBillImage(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_isAnalyzingImage) return;

    try {
      final selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (selectedImage == null) return;

      await _analyzeBillImagePath(
        selectedImage.path,
        docs,
        emptyMessage: 'No known item detected. Use a clearer image with visible product text.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _billingScanMessage = 'Image upload failed. Please retry.');
    }
  }

  Future<void> _analyzeBillImagePath(
    String imagePath,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String emptyMessage,
  }) async {
    if (_isAnalyzingImage) return;

    setState(() {
      _isAnalyzingImage = true;
      _billingScanMessage = 'Analyzing image...';
    });

    try {
      final inventoryByName = {
        for (final doc in docs)
          (doc.data()['name'] ?? '').toString().toLowerCase().trim(): doc,
      };

      final detections = await _visionAgent.analyzeImage(
        imagePath: imagePath,
        inventoryNames: docs.map((d) => (d.data()['name'] ?? '').toString()).toList(),
      );

      _applyDetectionsToCart(detections, inventoryByName);

      if (!mounted) return;
      setState(() {
        _billingScanMessage = detections.isEmpty
            ? emptyMessage
            : 'Detected ${detections.length} item(s). Review quantities below.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _billingScanMessage = 'Image analysis failed. Please retry.');
    } finally {
      if (!mounted) return;
      setState(() => _isAnalyzingImage = false);
    }
  }

  void _applyDetectionsToCart(
    List<KiranaDetection> detections,
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> inventoryByName,
  ) {
    if (detections.isEmpty) return;

    final updates = <String, int>{};
    for (final detection in detections) {
      final doc = _resolveInventoryDoc(detection.label, inventoryByName);
      if (doc == null) continue;
      final current = cart[doc.id] ?? 0;
      updates[doc.id] = current + detection.suggestedQuantity;
    }

    if (updates.isNotEmpty) {
      setState(() => cart.addAll(updates));
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _resolveInventoryDoc(
    String label,
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> inventoryByName,
  ) {
    final normalizedLabel = label.toLowerCase().trim();
    if (normalizedLabel.isEmpty) return null;

    final exact = inventoryByName[normalizedLabel];
    if (exact != null) return exact;

    final tokens = normalizedLabel
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList();

    QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
    var bestScore = 0;

    for (final entry in inventoryByName.entries) {
      final candidateName = entry.key;
      if (candidateName.contains(normalizedLabel) || normalizedLabel.contains(candidateName)) {
        return entry.value;
      }

      var score = 0;
      for (final token in tokens) {
        if (candidateName.contains(token)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestDoc = entry.value;
      }
    }

    return bestScore > 0 ? bestDoc : null;
  }

  Future<void> _generateBill(List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs) async {
    if (cart.values.every((qty) => qty <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to generate a bill')),
      );
      return;
    }

    final items = <Map<String, dynamic>>[];
    var skippedOutOfStock = 0;
    for (final doc in inventoryDocs) {
      final qty = cart[doc.id] ?? 0;
      if (qty <= 0) continue;
      final data = doc.data();
      final stock = _asInt(data['stock']);
      if (qty > stock) {
        skippedOutOfStock++;
        continue;
      }

      final price = _asInt(data['price']);

      items.add({
        'itemId': doc.id,
        'name': data['name'],
        'qty': qty,
        'price': price,
      });

      await doc.reference.update({'stock': stock - qty, 'updatedAt': Timestamp.now()});
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bill created. Adjust quantities and try again.')),
      );
      return;
    }

    final createdAt = Timestamp.now();
    final itemCount = items.fold<int>(0, (sum, item) => sum + _asInt(item['qty']));
    final total = items.fold<int>(0, (sum, item) => sum + _asInt(item['qty']) * _asInt(item['price']));

    final billRef = await FirestoreService.bills.add({
      'items': items,
      'itemCount': itemCount,
      'total': total,
      'createdAt': createdAt,
    });

    if (mounted) {
      setState(cart.clear);
      if (skippedOutOfStock > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$skippedOutOfStock item(s) exceeded stock and were skipped')),
        );
      }
      _showBillPreview(
        billNumber: billRef.id.substring(0, 8).toUpperCase(),
        createdAt: createdAt.toDate(),
        itemCount: itemCount,
        total: total,
        items: items,
      );
    }
  }

  Future<void> _showBillPreview({
    required String billNumber,
    required DateTime createdAt,
    required int itemCount,
    required int total,
    required List<Map<String, dynamic>> items,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  const Center(
                    child: Text(
                      'Invoice / Bill',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Bill No: $billNumber'),
                  Text('Date: ${_formatDateTime(createdAt)}'),
                  const Divider(height: 30),
                  ...items.map((item) {
                    final qty = _asInt(item['qty']);
                    final price = _asInt(item['price']);
                    final amount = qty * price;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['name']?.toString() ?? 'Unnamed Item',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('$qty x ₹$price'),
                          const SizedBox(width: 12),
                          Text(
                            '₹$amount',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Items'),
                      Text('$itemCount'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹$total',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openHistoryBillPreview(QueryDocumentSnapshot<Map<String, dynamic>> billDoc) async {
    final data = billDoc.data();
    final rawItems = (data['items'] as List<dynamic>? ?? []);
    final items = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
        .toList();
    final createdAtTimestamp = data['createdAt'] as Timestamp?;
    final createdAt = createdAtTimestamp?.toDate() ?? DateTime.now();

    final itemCount = _asInt(data['itemCount']);
    final total = _asInt(data['total']);

    await _showBillPreview(
      billNumber: billDoc.id.substring(0, 8).toUpperCase(),
      createdAt: createdAt,
      itemCount: itemCount,
      total: total,
      items: items,
    );
  }

  Widget _buildBillingHistory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.bills.orderBy('createdAt', descending: true).limit(15).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 74,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final billDocs = snapshot.data?.docs ?? [];
        if (billDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.history_toggle_off),
                title: Text('Billing history'),
                subtitle: Text('No past bills yet. Generate your first bill.'),
              ),
            ),
          );
        }

        return SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            itemCount: billDocs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final billDoc = billDocs[index];
              final bill = billDoc.data();
              final createdAt = (bill['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final total = _asInt(bill['total']);
              final isSelected = _selectedHistoryBillId == billDoc.id;

              return SizedBox(
                width: 220,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    setState(() => _selectedHistoryBillId = billDoc.id);
                    await _openHistoryBillPreview(billDoc);
                  },
                  child: Card(
                    elevation: isSelected ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? const Color(0xff4e73df) : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill ${billDoc.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(createdAt),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            '₹$total',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
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
        title: const Text('New Bill', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.inventory.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load inventory right now.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = docs.where((doc) {
            final name = (doc.data()['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchText);
          }).toList();
          final total = _total(docs);

          return Column(
            children: [
              _buildBillingHistory(),
              Container(
                height: 220,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _cameraError != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _cameraError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              )
                            : _controller == null
                                ? const Center(child: CircularProgressIndicator())
                                : FutureBuilder(
                                    future: _initializeControllerFuture,
                                    builder: (context, cameraSnapshot) {
                                      if (cameraSnapshot.connectionState == ConnectionState.done) {
                                        return CameraPreview(_controller!);
                                      }
                                      return const Center(child: CircularProgressIndicator());
                                    },
                                  ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: ElevatedButton.icon(
                          onPressed: docs.isEmpty || _isAnalyzingImage ? null : () => _analyzeBillFrame(docs),
                          icon: _isAnalyzingImage
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(_isAnalyzingImage ? 'Analyzing...' : 'Analyze Frame'),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: ElevatedButton.icon(
                          onPressed: docs.isEmpty || _isAnalyzingImage ? null : () => _analyzeUploadedBillImage(docs),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload from Device'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_billingScanMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _billingScanMessage!,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search billing item...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? const Center(child: Text('No inventory items found for this search.'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final data = doc.data();
                                final stock = _asInt(data['stock']);
                                final price = _asInt(data['price']);
                                final qty = cart[doc.id] ?? 0;

                                return ListTile(
                                  tileColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: Text(data['name'] ?? 'Unnamed'),
                                  subtitle: Text('₹$price • Stock: $stock'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: qty > 0 ? () => setState(() => cart[doc.id] = qty - 1) : null,
                                      ),
                                      Text('$qty'),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: qty < stock ? () => setState(() => cart[doc.id] = qty + 1) : null,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount'),
                        Text('₹$total',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff4e73df))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: docs.isEmpty || total <= 0 ? null : () => _generateBill(docs),
                        child: const Text('Generate Bill'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
