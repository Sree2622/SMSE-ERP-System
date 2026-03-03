import 'package:flutter/material.dart';

class InventoryScreen extends StatelessWidget {

  final List<Map<String, dynamic>> items = [
    {"name": "Maggi", "stock": 25},
    {"name": "Parle-G", "stock": 12},
    {"name": "Tata Salt", "stock": 5},
  ];

  Color getStockColor(int stock) {
    if (stock <= 5) return Colors.red;
    if (stock <= 15) return Colors.orange;
    return Colors.green;
  }

  String getStockLabel(int stock) {
    if (stock <= 5) return "Low Stock";
    if (stock <= 15) return "Medium";
    return "In Stock";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff5f7fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "Inventory",
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xff4e73df),
        onPressed: () {
          // TODO: Add item
        },
        child: Icon(Icons.add),
      ),

      body: Column(
        children: [

          /// Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search item...",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          /// Inventory List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final stock = item["stock"];

                return Container(
                  margin: EdgeInsets.only(bottom: 14),
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
                                fontWeight:
                                    FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "$stock units",
                            style: TextStyle(
                                color: Colors.grey[600]),
                          ),
                        ],
                      ),

                      /// Stock Status + Edit
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6),
                            decoration: BoxDecoration(
                              color: getStockColor(stock)
                                  .withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              getStockLabel(stock),
                              style: TextStyle(
                                color:
                                    getStockColor(stock),
                                fontWeight:
                                    FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              // TODO: Edit item
                            },
                            icon: Icon(
                              Icons.edit,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}