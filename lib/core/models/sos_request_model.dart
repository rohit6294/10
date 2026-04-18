import 'package:cloud_firestore/cloud_firestore.dart';

class SosRequestModel {
  final String id;
  final double latitude;
  final double longitude;
  final String mapsLink;
  final String status; // pending | assigned | resolved
  final String? driverId;
  final DateTime? createdAt;

  const SosRequestModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.mapsLink,
    required this.status,
    this.driverId,
    this.createdAt,
  });

  factory SosRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SosRequestModel(
      id: doc.id,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      mapsLink: data['mapsLink'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      driverId: data['driverId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
