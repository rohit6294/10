import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/driver_model.dart';
import '../../../core/models/rescue_request_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _loading = false;

  final _dismissedRequestIds = <String>{};
  bool _navigating = false;

  Position? _currentPosition;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigating = false;
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  void _handlePendingRequests(List<RescueRequestModel> requests) {
    if (_navigating) return;

    for (final req in requests) {
      if (_dismissedRequestIds.contains(req.requestId)) continue;

      if (_currentPosition != null) {
        final dist = LocationService.distanceKm(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          req.patientLocation.latitude,
          req.patientLocation.longitude,
        );
        if (dist > 10) continue;
      }

      _dismissedRequestIds.add(req.requestId);
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/driver/request/${req.requestId}');
      });
      return;
    }
  }

  Future<void> _toggleOnline(bool currentlyOnline) async {
    if (!currentlyOnline) {
      final granted = await _locationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to go online.'),
            backgroundColor: AppColors.emergency,
          ),
        );
        return;
      }
    }
    setState(() => _loading = true);
    try {
      await _firestoreService.setDriverOnline(_uid, !currentlyOnline);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text('10Min Rescue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) context.go('/auth/login'); // ← fixed route
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        child: StreamBuilder<DriverModel>(
          stream: _firestoreService.watchDriver(_uid),
          builder: (context, snapshot) {
            // Show meaningful error instead of spinning forever
            if (snapshot.hasError) {
              final err = snapshot.error.toString();
              final isPermission = err.contains('permission-denied') ||
                  err.contains('PERMISSION_DENIED');
              return _buildErrorState(
                icon: isPermission
                    ? Icons.lock_outline_rounded
                    : Icons.cloud_off_rounded,
                title: isPermission
                    ? 'Database Access Denied'
                    : 'Database Not Set Up',
                message: isPermission
                    ? 'Firestore security rules are blocking access.\nAsk admin to set rules to Test mode.'
                    : 'Firestore database is not created yet.\nGo to Firebase Console → Firestore Database → Create database.',
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.emergency),
                    SizedBox(height: 16),
                    Text('Loading your profile...',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }

            final driver = snapshot.data!;

            return StreamBuilder<List<RescueRequestModel>>(
              stream: (driver.isOnline && driver.isAvailable)
                  ? _firestoreService.watchPendingDriverRequests()
                  : const Stream.empty(),
              builder: (context, reqSnap) {
                if (reqSnap.hasData && reqSnap.data!.isNotEmpty) {
                  _handlePendingRequests(reqSnap.data!);
                }
                return _buildBody(driver);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.emergency, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) context.go('/auth/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(DriverModel driver) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Driver Avatar & Name
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.drive_eta_rounded,
                      color: AppColors.accentBlue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name.isEmpty ? 'Driver' : driver.name,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        driver.vehicleNumber.isEmpty
                            ? 'Vehicle not set'
                            : driver.vehicleNumber,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Online/Offline Toggle Card
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: driver.isOnline
                    ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                    : [AppColors.navy, AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (driver.isOnline
                          ? const Color(0xFF16A34A)
                          : AppColors.navy)
                      .withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  driver.isOnline
                      ? Icons.sensors_rounded
                      : Icons.sensors_off_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  driver.isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  driver.isOnline
                      ? 'Waiting for emergency requests...'
                      : 'Toggle to start receiving requests',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _toggleOnline(driver.isOnline),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: driver.isOnline
                          ? Colors.white.withOpacity(0.15)
                          : AppColors.emergency,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 3),
                    ),
                    child: Icon(
                      driver.isOnline
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  driver.isOnline ? 'Tap to go Offline' : 'Tap to go Online',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status info
          if (driver.isOnline && driver.currentRequestId != null)
            _statusTile(
              icon: Icons.emergency_rounded,
              color: AppColors.emergency,
              title: 'Active Request',
              subtitle: 'Tap to view current request',
              onTap: () => context
                  .go('/driver/navigate-patient/${driver.currentRequestId}'),
            )
          else if (driver.isOnline)
            _statusTile(
              icon: Icons.check_circle_outline,
              color: AppColors.onlineGreen,
              title: 'Ready for Requests',
              subtitle: "You'll be notified when there's an emergency nearby",
            ),
        ],
      ),
    );
  }

  Widget _statusTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.textLight, size: 14),
          ],
        ),
      ),
    );
  }
}
