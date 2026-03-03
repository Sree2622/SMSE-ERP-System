import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff5f7fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "Reports & Analytics",
          style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// Revenue Overview Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Color(0xff4e73df), Color(0xff224abe)],
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Revenue",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "₹12,450",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "+8% from yesterday",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.trending_up,
                      color: Colors.white, size: 40)
                ],
              ),
            ),

            SizedBox(height: 25),

            /// KPI Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: [

                _reportTile(
                  icon: Icons.shopping_cart,
                  title: "Total Orders",
                  value: "34",
                  color: Colors.orange,
                ),

                _reportTile(
                  icon: Icons.star,
                  title: "Top Item",
                  value: "Maggi",
                  color: Colors.green,
                ),

                _reportTile(
                  icon: Icons.inventory,
                  title: "Low Stock Items",
                  value: "3",
                  color: Colors.red,
                ),

                _reportTile(
                  icon: Icons.people,
                  title: "Customers Today",
                  value: "27",
                  color: Colors.purple,
                ),
              ],
            ),

            SizedBox(height: 25),

            /// Recent Activity Section
            Text(
              "Recent Activity",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 15),

            Container(
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
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.receipt_long,
                        color: Colors.blue),
                    title: Text("Bill #1023 Generated"),
                    subtitle: Text("₹540 • 10:32 AM"),
                  ),
                  Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.warning,
                        color: Colors.red),
                    title: Text("Low stock alert: Tata Salt"),
                    subtitle: Text("Only 5 units remaining"),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _reportTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
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
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                color.withOpacity(0.15),
            child: Icon(icon,
                color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}