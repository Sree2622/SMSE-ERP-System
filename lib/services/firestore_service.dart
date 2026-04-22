import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get inventory =>
      db.collection('inventory_items');

  static CollectionReference<Map<String, dynamic>> get bills =>
      db.collection('bills');

  static DocumentReference<Map<String, dynamic>> get shopProfile =>
      db.collection('settings').doc('shop_profile');

  static Future<double> fetchTodayRevenue() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final startTs = Timestamp.fromDate(start);

    final snapshot = await bills
        .where('createdAt', isGreaterThanOrEqualTo: startTs)
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      final amount = doc.data()['total'] ?? 0;
      if (amount is int) total += amount.toDouble();
      if (amount is double) total += amount;
    }
    return total;
  }
}
