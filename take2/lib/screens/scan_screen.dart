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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _scanMessage = 'No camera available on this device.';
          _isCameraLoading = false;
        });
        return;
      }

      final preferred = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        preferred,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
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
      if (!mounted) return;
      setState(() {
        _isCameraLoading = false;
        _scanMessage = 'Camera setup failed. Please check permissions.';
      });
    }
  }

  Future<void> _analyzeFrame(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_isAnalyzing || _cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final image = await _cameraController!.takePicture();
      await _analyzeImagePath(image.path, docs, emptyMessage: 'No known kirana item detected. Try better lighting or angle.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanMessage = 'Frame analysis failed. Please retry.';
      });
    }
  }

  Future<void> _analyzeUploadedImage(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_isAnalyzing) return;

    try {
      final selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (selectedImage == null) return;

      await _analyzeImagePath(selectedImage.path, docs, emptyMessage: 'No known kirana item detected. Try another image.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanMessage = 'Image upload failed. Please retry.';
      });
    }
  }

  Future<void> _analyzeImagePath(
    String imagePath,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String emptyMessage,
  }) async {
    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _scanMessage = 'Analyzing image...';
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

      _applyDetections(detections, inventoryByName);

      if (!mounted) return;
      setState(() {
        _scanMessage = detections.isEmpty ? emptyMessage : 'Detected ${detections.length} item(s). Review quantities below.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanMessage = 'Image analysis failed. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _applyDetections(
    List<KiranaDetection> detections,
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> inventoryByName,
  ) {
    if (detections.isEmpty) return;

    final updates = <String, int>{};
    for (final detection in detections) {
      final doc = _resolveInventoryDoc(detection.label, inventoryByName);
      if (doc == null) continue;

      final existing = scannedQty[doc.id] ?? 0;
      updates[doc.id] = existing + detection.suggestedQuantity;
    }

    if (updates.isNotEmpty) {
      setState(() {
        scannedQty.addAll(updates);
      });
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

  Future<void> _saveScannedStock(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    for (final doc in docs) {
      final qty = scannedQty[doc.id] ?? 0;
      if (qty <= 0) continue;
      final current = (doc.data()['stock'] ?? 0) as int;
      await doc.reference.update({'stock': current + qty, 'updatedAt': Timestamp.now()});
    }

    await FirestoreService.db.collection('scan_logs').add({
      'items': scannedQty.entries.where((e) => e.value > 0).map((e) => {'itemId': e.key, 'qty': e.value}).toList(),
      'createdAt': Timestamp.now(),
      'source': 'camera_llm_agent',
    });

    if (mounted) {
      setState(scannedQty.clear);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanned stock saved to Firebase')));
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
        title: const Text('Scan Stock', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.inventory.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return Column(
            children: [
              Container(
                height: 240,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: _isCameraLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_cameraController?.value.isInitialized ?? false)
                        ? Stack(
                            children: [
                              Positioned.fill(child: CameraPreview(_cameraController!)),
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: ElevatedButton.icon(
                                  onPressed: docs.isEmpty || _isAnalyzing ? null : () => _analyzeFrame(docs),
                                  icon: _isAnalyzing
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.auto_awesome),
                                  label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Frame'),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: ElevatedButton.icon(
                                  onPressed: docs.isEmpty || _isAnalyzing ? null : () => _analyzeUploadedImage(docs),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload from Device'),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _scanMessage ?? 'Camera unavailable',
                                  style: const TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: docs.isEmpty || _isAnalyzing ? null : () => _analyzeUploadedImage(docs),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload from Device'),
                                ),
                              ],
                            ),
                          ),
              ),
              if (_scanMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_scanMessage!, style: const TextStyle(color: Colors.black54)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Detected Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${scannedQty.values.where((v) => v > 0).length} items'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final qty = scannedQty[doc.id] ?? 0;

                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(data['name'] ?? 'Unnamed'),
                      subtitle: Text('Detected quantity: $qty'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: qty > 0 ? () => setState(() => scannedQty[doc.id] = qty - 1) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          IconButton(
                            onPressed: () => setState(() => scannedQty[doc.id] = qty + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: docs.isEmpty ? null : () => _saveScannedStock(docs),
                    child: const Text('Confirm & Save'),
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
