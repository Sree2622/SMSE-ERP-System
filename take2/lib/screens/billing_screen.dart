import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class BillingScreen extends StatefulWidget {
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  List<Map<String, dynamic>> cart = [
    {"name": "Maggi", "qty": 2, "price": 15},
    {"name": "Parle-G", "qty": 1, "price": 10},
  ];

  int get total =>
      cart.fold(0, (sum, item) => sum + (item["qty"] * item["price"] as int));

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void increaseQty(int index) {
    setState(() {
      cart[index]["qty"]++;
    });
  }

  void decreaseQty(int index) {
    setState(() {
      if (cart[index]["qty"] > 1) {
        cart[index]["qty"]--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "New Bill",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),

      body: Column(
        children: [

          /// 📷 CAMERA PREVIEW SECTION
          Container(
            height: 220,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _controller == null
                  ? Center(child: CircularProgressIndicator())
                  : FutureBuilder(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.done) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [

                              /// Live Camera
                              CameraPreview(_controller!),

                              /// Scanning Frame Overlay
                              Container(
                                width: 200,
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Color(0xff4e73df),
                                    width: 3,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                              ),

                              Positioned(
                                bottom: 10,
                                child: Text(
                                  "Scan barcode here",
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12),
                                ),
                              )
                            ],
                          );
                        } else {
                          return Center(
                              child: CircularProgressIndicator());
                        }
                      },
                    ),
            ),
          ),

          /// 🛒 Cart Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [

                      /// Item Info
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["name"],
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "₹${item["price"]} each",
                            style: TextStyle(
                                color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      /// Quantity Controls
                      Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                decreaseQty(index),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            "${item["qty"]}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          IconButton(
                            onPressed: () =>
                                increaseQty(index),
                            icon: Icon(Icons.add_circle_outline),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "₹${item["qty"] * item["price"]}",
                            style: TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          /// 💰 Bottom Summary Panel
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Amount",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      "₹$total",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff4e73df)),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff4e73df),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // TODO: Generate bill logic
                    },
                    child: Text(
                      "Generate Bill",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}