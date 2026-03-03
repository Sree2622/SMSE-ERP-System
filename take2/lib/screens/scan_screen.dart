import 'package:flutter/material.dart';

class ScanScreen extends StatelessWidget {
  final List<Map<String, dynamic>> detectedItems = [
    {"name": "Maggi", "qty": 5},
    {"name": "Parle-G", "qty": 10},
    {"name": "Surf Excel", "qty": 3},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff5f7fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "Scan Stock",
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold),
        ),
      ),

      body: Column(
        children: [

          /// Camera Preview Section
          Container(
            height: 250,
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [

                /// Camera Icon Placeholder
                Icon(
                  Icons.camera_alt,
                  color: Colors.white54,
                  size: 80,
                ),

                /// Scanning Frame Overlay
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color(0xff4e73df),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                Positioned(
                  bottom: 15,
                  child: Text(
                    "Align barcode within frame",
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12),
                  ),
                )
              ],
            ),
          ),

          /// Detected Items Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Detected Items",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "${detectedItems.length} items",
                  style: TextStyle(
                      color: Colors.grey[600]),
                )
              ],
            ),
          ),

          SizedBox(height: 10),

          /// Detected Items List
          Expanded(
            child: ListView.builder(
              padding:
                  EdgeInsets.symmetric(horizontal: 16),
              itemCount: detectedItems.length,
              itemBuilder: (context, index) {
                final item = detectedItems[index];

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
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

                      /// Item Name
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["name"],
                            style: TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                                fontSize: 16),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Quantity: ${item["qty"]}",
                            style: TextStyle(
                                color:
                                    Colors.grey[600]),
                          ),
                        ],
                      ),

                      /// Confirm Icon
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            Colors.green.withOpacity(0.15),
                        child: Icon(
                          Icons.check,
                          color: Colors.green,
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          /// Bottom Action Panel
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
            child: SizedBox(
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
                  // TODO: Save scanned stock
                },
                child: Text(
                  "Confirm & Save",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}