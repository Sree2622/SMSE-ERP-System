import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff5f7fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black87),
        title: Text(
          "Settings",
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

            /// Shop Profile Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Color(0xff4e73df), Color(0xff224abe)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.store,
                        color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ramesh Kirana Store",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "GST: 22ABCDE1234F1Z5",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            SizedBox(height: 30),

            /// General Section
            Text(
              "General",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 15),

            _settingsTile(
              icon: Icons.edit,
              title: "Edit Shop Details",
              subtitle: "Update name, GST & address",
              onTap: () {},
            ),

            _settingsTile(
              icon: Icons.print,
              title: "Printer Settings",
              subtitle: "Thermal printer setup",
              onTap: () {},
            ),

            SizedBox(height: 25),

            /// Preferences Section
            Text(
              "Preferences",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 15),

            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
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
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isDarkMode,
                onChanged: (value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
                title: Text(
                  "Dark Mode",
                  style: TextStyle(
                      fontWeight: FontWeight.w600),
                ),
                secondary: Icon(Icons.dark_mode),
              ),
            ),

            SizedBox(height: 25),

            /// About Section
            Text(
              "About",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 15),

            _settingsTile(
              icon: Icons.info_outline,
              title: "App Version",
              subtitle: "v1.0.0",
              onTap: () {},
            ),

            _settingsTile(
              icon: Icons.logout,
              title: "Logout",
              subtitle: "Sign out from this device",
              onTap: () {},
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: isDestructive
              ? Colors.red
              : Colors.black87,
        ),
        title: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDestructive
                  ? Colors.red
                  : Colors.black87),
        ),
        subtitle: Text(subtitle),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}