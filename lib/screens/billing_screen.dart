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
  bool _scanMessageIsError = false;
  final KiranaVisionAgent _visionAgent = KiranaVisionAgent();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();

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

      _controller = CameraController(cameras.first, ResolutionPreset.medium,
          enableAudio: false);
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
    _searchController.dispose();
    super.dispose();
  }

  int get _cartItemCount => cart.values.fold(0, (a, b) => a + b);

  int _total(List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs) {
    var sum = 0;
    for (final doc in inventoryDocs) {
      final qty = cart[doc.id] ?? 0;
      final price = _asInt(doc.data()['price']);
      sum += qty * price;
    }
    return sum;
  }

  Future<String?> _showDummyPaymentGateway(int amount) async {
    var selectedMethod = 'UPI';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payment, color: Color(0xff4e73df)),
              SizedBox(width: 8),
              Text('Dummy Payment Gateway'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount to collect: ₹$amount',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text(
                'This is a demo payment flow (no real transaction).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, selectedMethod),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Pay Now (Dummy)'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearCart() {
    setState(() {
      cart.clear();
      _billingScanMessage = null;
    });
  }

  Future<void> _analyzeBillFrame(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_isAnalyzingImage ||
        _controller == null ||
        !(_controller!.value.isInitialized)) return;

    try {
      final image = await _controller!.takePicture();
      await _analyzeBillImagePath(
        image.path,
        docs,
        emptyMessage:
            'No known item detected. Try better lighting or angle.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _billingScanMessage = 'Frame analysis failed. Please retry.';
        _scanMessageIsError = true;
      });
    }
  }

  Future<void> _analyzeUploadedBillImage(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
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
        emptyMessage: 'No known item detected. Try another image.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _billingScanMessage = 'Image upload failed. Please retry.';
        _scanMessageIsError = true;
      });
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
      _billingScanMessage = 'Analyzing image…';
      _scanMessageIsError = false;
    });

    try {
      final inventoryByName = {
        for (final doc in docs)
          (doc.data()['name'] ?? '').toString().toLowerCase().trim(): doc,
      };

      final detections = await _visionAgent.analyzeImage(
        imagePath: imagePath,
        inventoryNames:
            docs.map((d) => (d.data()['name'] ?? '').toString()).toList(),
      );

      if (!mounted) return;

      if (detections.isEmpty) {
        setState(() {
          _billingScanMessage = emptyMessage;
          _scanMessageIsError = true;
          _isAnalyzingImage = false;
        });
        return;
      }

      // Show confirmation before adding to cart
      await _showDetectionConfirmDialog(detections, inventoryByName);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _billingScanMessage = 'Image analysis failed. Please retry.';
        _scanMessageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isAnalyzingImage = false);
    }
  }

  Future<void> _showDetectionConfirmDialog(
    List<KiranaDetection> detections,
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> inventoryByName,
  ) async {
    final pairs = <_DetectionPair>[];
    for (final det in detections) {
      final doc = _resolveInventoryDoc(det.label, inventoryByName);
      pairs.add(_DetectionPair(detection: det, doc: doc));
    }

    final confirmed = {for (final p in pairs) p: p.doc != null};

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.checklist_rtl, color: Color(0xff4e73df)),
              SizedBox(width: 8),
              Text('Confirm Items'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review detected items before adding to cart.',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                ...pairs.map((pair) {
                  final pct =
                      (pair.detection.confidence * 100).toStringAsFixed(0);
                  final isMatched = pair.doc != null;
                  final name = isMatched
                      ? (pair.doc!.data()['name'] ?? pair.detection.label)
                      : pair.detection.label;
                  final price = isMatched
                      ? _asInt(pair.doc!.data()['price'])
                      : 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isMatched
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isMatched
                              ? Colors.green.shade200
                              : Colors.orange.shade300),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      value: confirmed[pair] ?? false,
                      onChanged: isMatched
                          ? (val) => setDialogState(
                              () => confirmed[pair] = val ?? false)
                          : null,
                      title: Text(name.toString(),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        isMatched
                            ? '₹$price • Confidence: $pct%'
                            : '⚠ Not in inventory • $pct%',
                        style: TextStyle(
                            fontSize: 11,
                            color: isMatched
                                ? Colors.grey.shade600
                                : Colors.orange),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              onPressed: () {
                int added = 0;
                for (final pair in pairs) {
                  if ((confirmed[pair] ?? false) && pair.doc != null) {
                    final current = cart[pair.doc!.id] ?? 0;
                    cart[pair.doc!.id] =
                        current + pair.detection.suggestedQuantity;
                    added++;
                  }
                }
                setState(() {
                  _billingScanMessage = added > 0
                      ? '$added item(s) added to cart.'
                      : 'No items confirmed.';
                  _scanMessageIsError = false;
                });
                Navigator.pop(ctx);
              },
              label: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
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
      if (candidateName.contains(normalizedLabel) ||
          normalizedLabel.contains(candidateName)) {
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

  Future<void> _generateBill(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> inventoryDocs) async {
    if (cart.values.every((qty) => qty <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one item to generate a bill')),
      );
      return;
    }

    final items = <Map<String, dynamic>>[];
    final stockUpdates = <Map<String, dynamic>>[];
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
      stockUpdates.add({
        'ref': doc.reference,
        'nextStock': stock - qty,
      });
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No bill created. Adjust quantities and try again.')),
      );
      return;
    }

    final createdAt = Timestamp.now();
    final itemCount =
        items.fold<int>(0, (sum, item) => sum + _asInt(item['qty']));
    final total = items.fold<int>(
        0,
        (sum, item) =>
            sum + _asInt(item['qty']) * _asInt(item['price']));
    final paymentMethod = await _showDummyPaymentGateway(total);
    if (paymentMethod == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled. Bill was not created.')),
        );
      }
      return;
    }

    for (final update in stockUpdates) {
      final ref = update['ref'] as DocumentReference<Map<String, dynamic>>;
      final nextStock = _asInt(update['nextStock']);
      await ref.update({'stock': nextStock, 'updatedAt': Timestamp.now()});
    }

    final billRef = await FirestoreService.bills.add({
      'items': items,
      'itemCount': itemCount,
      'total': total,
      'createdAt': createdAt,
      'payment': {
        'gateway': 'DummyPay',
        'status': 'success',
        'method': paymentMethod,
        'paidAt': createdAt,
        'isDummy': true,
      },
    });

    if (mounted) {
      setState(cart.clear);
      if (skippedOutOfStock > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$skippedOutOfStock item(s) exceeded stock and were skipped')),
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      '🧾  Invoice / Bill',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _billRow('Bill No', billNumber),
                        _billRow('Date', _formatDateTime(createdAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ...items.map((item) {
                    final qty = _asInt(item['qty']);
                    final price = _asInt(item['price']);
                    final amount = qty * price;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item['name']?.toString() ?? 'Unnamed Item',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('$qty × ₹$price',
                              style: TextStyle(
                                  color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Text('₹$amount',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 30),
                  _billRow('Total Items', '$itemCount'),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('₹$total',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff4e73df))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
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

  Widget _billRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _openHistoryBillPreview(
      QueryDocumentSnapshot<Map<String, dynamic>> billDoc) async {
    final data = billDoc.data();
    final rawItems = (data['items'] as List<dynamic>? ?? []);
    final items = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item))
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
      stream: FirestoreService.bills
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
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
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.history_toggle_off),
                title: Text('Billing history'),
                subtitle:
                    Text('No past bills yet. Generate your first bill.'),
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
              final createdAt =
                  (bill['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();
              final total = _asInt(bill['total']);
              final isSelected = _selectedHistoryBillId == billDoc.id;

              return SizedBox(
                width: 220,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    setState(() => _selectedHistoryBillId = billDoc.id);
                    await _openHistoryBillPreview(billDoc);
                    if (mounted) setState(() => _selectedHistoryBillId = null);
                  },
                  child: Card(
                    elevation: isSelected ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xff4e73df)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill ${billDoc.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(createdAt),
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12),
                          ),
                          const Spacer(),
                          Text('₹$total',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
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
        title: const Text('New Bill',
            style: TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          if (_cartItemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: _clearCart,
                icon: const Icon(Icons.remove_shopping_cart,
                    color: Colors.redAccent, size: 18),
                label: const Text('Clear',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          if (_cartItemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.shopping_cart,
                    size: 14, color: Colors.white),
                label: Text('$_cartItemCount',
                    style: const TextStyle(color: Colors.white)),
                backgroundColor: const Color(0xff4e73df),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirestoreService.inventory.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Unable to load inventory right now.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = docs.where((doc) {
            final name =
                (doc.data()['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchText);
          }).toList();
          final total = _total(docs);

          return Column(
            children: [
              _buildBillingHistory(),

              // CAMERA
              Container(
                height: 200,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _cameraError != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.no_photography,
                                        color: Colors.white54,
                                        size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      _cameraError!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              )
                            : _controller == null
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : FutureBuilder(
                                    future:
                                        _initializeControllerFuture,
                                    builder: (context, cameraSnapshot) {
                                      if (cameraSnapshot.connectionState ==
                                          ConnectionState.done) {
                                        return CameraPreview(
                                            _controller!);
                                      }
                                      return const Center(
                                          child:
                                              CircularProgressIndicator());
                                    },
                                  ),
                      ),
                      if (_isAnalyzingImage)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                    color: Colors.white),
                                SizedBox(height: 8),
                                Text('Analyzing…',
                                    style: TextStyle(
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: docs.isEmpty ||
                                        _isAnalyzingImage
                                    ? null
                                    : () => _analyzeBillFrame(docs),
                                icon: _isAnalyzingImage
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.auto_awesome),
                                label: Text(_isAnalyzingImage
                                    ? 'Analyzing…'
                                    : 'Analyze Frame'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: docs.isEmpty || _isAnalyzingImage
                                  ? null
                                  : () =>
                                      _analyzeUploadedBillImage(docs),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SCAN MESSAGE
              if (_billingScanMessage != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin:
                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _scanMessageIsError
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _scanMessageIsError
                            ? Colors.red.shade200
                            : Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _scanMessageIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 14,
                        color: _scanMessageIsError
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _billingScanMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _scanMessageIsError
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ITEM LIST
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(
                            () => _searchText = value.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search item…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchText.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(
                                        () => _searchText = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? const Center(
                              child: Text(
                                  'No inventory items found for this search.'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final data = doc.data();
                                final stock =
                                    _asInt(data['stock']);
                                final price =
                                    _asInt(data['price']);
                                final qty =
                                    cart[doc.id] ?? 0;
                                final isOutOfStock = stock == 0;
                                final isInCart = qty > 0;

                                return Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isInCart
                                        ? const Color(0xff4e73df)
                                            .withOpacity(0.05)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: isInCart
                                        ? Border.all(
                                            color: const Color(
                                                    0xff4e73df)
                                                .withOpacity(0.3))
                                        : null,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      data['name'] ?? 'Unnamed',
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        color: isOutOfStock
                                            ? Colors.grey
                                            : null,
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text('₹$price'),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration:
                                              BoxDecoration(
                                            color: isOutOfStock
                                                ? Colors.red
                                                    .shade50
                                                : Colors.green
                                                    .shade50,
                                            borderRadius:
                                                BorderRadius
                                                    .circular(4),
                                          ),
                                          child: Text(
                                            isOutOfStock
                                                ? 'Out of stock'
                                                : '$stock left',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isOutOfStock
                                                  ? Colors.red
                                                  : Colors.green
                                                      .shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: isOutOfStock
                                        ? const Chip(
                                            label:
                                                Text('Unavailable'),
                                            backgroundColor:
                                                Color(0xFFFFEBEE),
                                          )
                                        : Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons
                                                    .remove_circle_outline),
                                                onPressed: qty >
                                                        0
                                                    ? () =>
                                                        setState(
                                                            () =>
                                                                cart[doc
                                                                    .id] =
                                                                    qty -
                                                                        1)
                                                    : null,
                                              ),
                                              Text(
                                                '$qty',
                                                style:
                                                    const TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons
                                                    .add_circle_outline),
                                                onPressed: qty <
                                                        stock
                                                    ? () =>
                                                        setState(
                                                            () =>
                                                                cart[doc
                                                                    .id] =
                                                                    qty +
                                                                        1)
                                                    : null,
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // TOTAL + GENERATE BILL
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Total Amount',
                                style: TextStyle(
                                    color: Colors.black54)),
                            Text(
                              '₹$total',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff4e73df)),
                            ),
                          ],
                        ),
                        if (_cartItemCount > 0)
                          Text(
                            '$_cartItemCount item(s) in cart',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: docs.isEmpty || total <= 0
                            ? null
                            : () => _generateBill(docs),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Generate Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xff4e73df),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
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

class _DetectionPair {
  final KiranaDetection detection;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  const _DetectionPair({required this.detection, required this.doc});
}
