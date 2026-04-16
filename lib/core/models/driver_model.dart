import 'package:cloud_firestore/cloud_firestore.dart';

class DriverModel {
  final String uid;
  final String name;
  final String phone;
  final String vehicleNumber;
  final String licenseNumber;
  final String fcmToken;
  final bool isOnline;
  final bool isAvailable;
  final GeoPoint? location;
  final String geohash;
  final String? currentRequestId;

  const DriverModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.vehicleNumber = '',
    this.licenseNumber = '',
    this.fcmToken = '',
    this.isOnline = false,
    this.isAvailable = true,
    this.location,
    this.geohash = '',
    this.currentRequestId,
  });

  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverModel(
      uid: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      vehicleNumber: data['vehicleNumber'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      isOnline: data['isOnline'] ?? false,
      isAvailable: data['isAvailable'] ?? true,
      location: data['location'] as GeoPoint?,
      geohash: data['geohash'] ?? '',
      currentRequestId: data['currentRequestId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'vehicleNumber': vehicleNumber,
        'licenseNumber': licenseNumber,
        'fcmToken': fcmToken,
        'isOnline': isOnline,
        'isAvailable': isAvailable,
        if (location != null) 'location': location,
        'geohash': geohash,
        'currentRequestId': currentRequestId,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      };

  DriverModel copyWith({
    bool? isOnline,
    bool? isAvailable,
    GeoPoint? location,
    String? geohash,
    String? currentRequestId,
    String? fcmToken,
  }) =>
      DriverModel(
        uid: uid,
        name: name,
        phone: phone,
        vehicleNumber: vehicleNumber,
        licenseNumber: licenseNumber,
        fcmToken: fcmToken ?? this.fcmToken,
        isOnline: isOnline ?? this.isOnline,
        isAvailable: isAvailable ?? this.isAvailable,
        location: location ?? this.location,
        geohash: geohash ?? this.geohash,
        currentRequestId: currentRequestId ?? this.currentRequestId,
      );
}
