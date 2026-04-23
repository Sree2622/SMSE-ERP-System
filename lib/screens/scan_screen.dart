import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/kirana_detection.dart';
import '../services/firestore_service.dart';
import '../services/kirana_vision_agent.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, int> scannedQty = {};
  final KiranaVisionAgent _visionAgent = KiranaVisionAgent();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _cameraController;
  bool _isCameraLoading = true;
  bool _isAnalyzing = false;

  String? _scanMessage;
  bool _scanMessageIsError = false;

  Future<void> _showItemDialog() async {
    final nameController = TextEditingController();
    final stockController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_box, color: Color(0xff4e73df)),
            SizedBox(width: 8),
            Text('Add Item'),
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
            child: const Text('Cancel'),
          ),
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

              await FirestoreService.inventory.add({
                'name': name,
                'stock': stock,
                'price': price,
                'createdAt': Timestamp.now(),
                'updatedAt': Timestamp.now(),
              });

              if (mounted) Navigator.pop(context);
            },
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // =========================
  // CAMERA INIT
  // =========================
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _scanMessage = 'No camera available on this device.';
          _scanMessageIsError = true;
          _isCameraLoading = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraLoading = false;
      });
    } catch (_) {
      setState(() {
        _scanMessage = 'Camera setup failed. You can still upload from gallery.';
        _scanMessageIsError = true;
        _isCameraLoading = false;
      });
    }
  }

  // =========================
  // ANALYZE IMAGE
  // =========================
  Future<void> _analyzeImagePath(
    String imagePath,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _scanMessage = 'Analyzing image…';
      _scanMessageIsError = false;
    });

    try {
      final detections = await _visionAgent.analyzeImage(
        imagePath: imagePath,
        inventoryNames: docs.map((d) => (d.data()['name'] ?? '').toString()).toList(),
      );

      if (!mounted) return;

      if (detections.isEmpty) {
        setState(() {
          _scanMessage = 'No items detected. Try better lighting or a clearer angle.';
          _scanMessageIsError = true;
        });
        return;
      }

      // Show confirmation dialog before applying
      await _showConfirmationDialog(detections, docs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanMessage = 'Analysis failed: $e';
        _scanMessageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  // =========================
  // CONFIRMATION DIALOG
  // =========================
  Future<void> _showConfirmationDialog(
    List<KiranaDetection> detections,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final inventory = {
      for (final d in docs)
        (d.data()['name'] ?? '').toString().toLowerCase(): d,
    };

    // Build a list of (detection, matchedDoc) pairs
    final pairs = <_DetectionPair>[];
    for (final det in detections) {
      final key = det.label.toLowerCase();
      QueryDocumentSnapshot<Map<String, dynamic>>? matched = inventory[key];

      // Fuzzy match if exact not found
      if (matched == null) {
        for (final entry in inventory.entries) {
          if (entry.key.contains(key) || key.contains(entry.key)) {
            matched = entry.value;
            break;
          }
        }
      }

      pairs.add(_DetectionPair(detection: det, doc: matched));
    }

    // Track which detections user confirms (default: all confirmed if matched)
    final confirmed = {for (final p in pairs) p: p.doc != null};

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.checklist_rtl, color: Color(0xff4e73df)),
                SizedBox(width: 8),
                Text('Confirm Detections'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review detected items. Uncheck any that are incorrect.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...pairs.map((pair) {
                    final confidencePct =
                        (pair.detection.confidence * 100).toStringAsFixed(0);
                    final isMatched = pair.doc != null;
                    final itemName = isMatched
                        ? (pair.doc!.data()['name'] ?? pair.detection.label)
                        : pair.detection.label;
                    final currentStock = isMatched
                        ? (pair.doc!.data()['stock'] ?? 0) as int
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
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: CheckboxListTile(
                        dense: true,
                        value: confirmed[pair] ?? false,
                        // Only allow confirming matched items
                        onChanged: isMatched
                            ? (val) => setDialogState(
                                () => confirmed[pair] = val ?? false)
                            : null,
                        title: Text(
                          itemName.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology,
                                    size: 12,
                                    color: _confidenceColor(
                                        pair.detection.confidence)),
                                const SizedBox(width: 4),
                                Text(
                                  'Confidence: $confidencePct%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _confidenceColor(
                                        pair.detection.confidence),
                                  ),
                                ),
                              ],
                            ),
                            if (isMatched)
                              Text(
                                'Current stock: $currentStock units',
                                style: const TextStyle(fontSize: 11),
                              )
                            else
                              const Text(
                                '⚠ Not found in inventory',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange),
                              ),
                          ],
                        ),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: isMatched
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            isMatched ? Icons.check : Icons.help_outline,
                            size: 16,
                            color: isMatched ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _scanMessage = 'Detection cancelled.';
                    _scanMessageIsError = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  // Apply only confirmed detections
                  int applied = 0;
                  for (final pair in pairs) {
                    if ((confirmed[pair] ?? false) && pair.doc != null) {
                      scannedQty[pair.doc!.id] =
                          (scannedQty[pair.doc!.id] ?? 0) + 1;
                      applied++;
                    }
                  }

                  Navigator.pop(ctx);

                  setState(() {
                    if (applied == 0) {
                      _scanMessage = 'No items confirmed. Nothing was added.';
                      _scanMessageIsError = false;
                    } else {
                      _scanMessage =
                          '$applied item(s) added to scan list. Tap Save to update stock.';
                      _scanMessageIsError = false;
                    }
                  });
                },
                icon: const Icon(Icons.add_task),
                label: const Text('Confirm & Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.75) return Colors.green.shade700;
    if (confidence >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  // =========================
  // CAMERA CAPTURE
  // =========================
  Future<void> _analyzeFromCamera(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) return;

    final image = await _cameraController!.takePicture();
    await _analyzeImagePath(image.path, docs);
  }

  // =========================
  // GALLERY PICK
  // =========================
  Future<void> _analyzeFromGallery(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _analyzeImagePath(picked.path, docs);
  }

  // =========================
  // SAVE TO FIRESTORE
  // =========================
  Future<void> _save(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final toSave = docs.where((d) => (scannedQty[d.id] ?? 0) > 0).toList();

    if (toSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to save. Scan some items first.')),
      );
      return;
    }

    for (final doc in toSave) {
      final qty = scannedQty[doc.id] ?? 0;
      final current = (doc.data()['stock'] ?? 0) as int;
      await doc.reference.update({
        'stock': current + qty,
        'updatedAt': Timestamp.now(),
      });
    }

    setState(() => scannedQty.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock updated for ${toSave.length} item(s).'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _scanMessage = null;
      });
    }
  }

  // =========================
  // CLEAR ALL
  // =========================
  void _clearAll() {
    setState(() {
      scannedQty.clear();
      _scanMessage = null;
      _scanMessageIsError = false;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _visionAgent.dispose();
    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Scan Stock',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (scannedQty.values.any((q) => q > 0))
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, color: Colors.redAccent),
              label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4e73df),
        onPressed: _showItemDialog,
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.inventory.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              // CAMERA PREVIEW
              Container(
                height: 240,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isCameraLoading)
                      const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                    else if (_cameraController != null)
                      CameraPreview(_cameraController!)
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.no_photography,
                                color: Colors.white54, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              _scanMessage ?? 'Camera unavailable',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    // Analyzing overlay
                    if (_isAnalyzing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text('Analyzing image…',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_isAnalyzing ||
                                _cameraController == null ||
                                !_cameraController!.value.isInitialized)
                            ? null
                            : () => _analyzeFromCamera(docs),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Capture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff4e73df),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _analyzeFromGallery(docs),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xff4e73df),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xff4e73df)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // STATUS MESSAGE
              if (_scanMessage != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _scanMessageIsError
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _scanMessageIsError
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _scanMessageIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 16,
                        color: _scanMessageIsError
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scanMessage!,
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

              // SCANNED ITEMS HEADER
              if (docs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scanned Items',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${scannedQty.values.fold(0, (a, b) => a + b)} units queued',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // SCANNED ITEMS LIST
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No inventory items found.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final qty = scannedQty[doc.id] ?? 0;
                          final name =
                              (data['name'] ?? 'Unnamed').toString();
                          final currentStock =
                              (data['stock'] ?? 0) as int;

                          if (qty == 0) return const SizedBox.shrink();

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
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                      color: Color(0xff4e73df),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  'Current stock: $currentStock → ${currentStock + qty}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent),
                                    onPressed: () => setState(() {
                                      if (qty > 1) {
                                        scannedQty[doc.id] = qty - 1;
                                      } else {
                                        scannedQty.remove(doc.id);
                                      }
                                    }),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.green),
                                    onPressed: () => setState(() =>
                                        scannedQty[doc.id] = qty + 1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // EMPTY STATE for list when nothing scanned yet
              if (docs.isNotEmpty &&
                  scannedQty.values.every((q) => q == 0))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Scan or upload an image to detect items.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // SAVE BUTTON
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: scannedQty.values.any((q) => q > 0)
                        ? () => _save(docs)
                        : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save to Inventory'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
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
