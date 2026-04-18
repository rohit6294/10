import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/sos_request_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/constants/app_colors.dart';

class SosActiveScreen extends StatefulWidget {
  final String sosId;
  const SosActiveScreen({super.key, required this.sosId});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> {
  final _fs = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _mapController = MapController();

  Position? _driverPos;
  StreamSubscription<Position>? _gpsSub;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) {
        if (mounted) setState(() => _driverPos = pos);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _openGoogleMaps(SosRequestModel sos) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${sos.latitude},${sos.longitude}&travelmode=driving';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open maps link
      final fallback = Uri.parse(sos.mapsLink);
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _complete(SosRequestModel sos) async {
    setState(() => _completing = true);
    try {
      await _fs.completeSosRequest(sos.id, _uid);
      if (mounted) context.go('/driver/home');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<SosRequestModel?>(
        stream: _fs.watchAssignedSos(_uid),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            // SOS was resolved or cancelled
            return _buildCompleted();
          }
          final sos = snap.data!;
          final customerLatLng = LatLng(sos.latitude, sos.longitude);
          final driverLatLng = _driverPos != null
              ? LatLng(_driverPos!.latitude, _driverPos!.longitude)
              : null;

          final distKm = driverLatLng != null
              ? _distanceKm(driverLatLng.latitude, driverLatLng.longitude,
                  sos.latitude, sos.longitude)
              : null;
          final etaMin = distKm != null ? (distKm / 40 * 60).round() : null;

          return Stack(
            children: [
              // ── Full-screen map ──────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: customerLatLng,
                  initialZoom: 14.5,
                ),
                children: [
                  // OSM tiles (free, no API key)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.tenminrescue.ten_min_res',
                  ),

                  // Route line
                  if (driverLatLng != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [driverLatLng, customerLatLng],
                          strokeWidth: 4,
                          color: AppColors.accentBlue.withValues(alpha: 0.85),
                        ),
                      ],
                    ),

                  // Markers
                  MarkerLayer(
                    markers: [
                      // Customer — red pulsing marker
                      Marker(
                        point: customerLatLng,
                        width: 60,
                        height: 60,
                        child: _CustomerMarker(),
                      ),
                      // Driver — blue car marker
                      if (driverLatLng != null)
                        Marker(
                          point: driverLatLng,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentBlue
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: const Icon(Icons.directions_car_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // ── Top bar ────────────────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emergency.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚨 ACTIVE SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Navigate to customer location',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Center map button
                      GestureDetector(
                        onTap: () => _mapController.move(customerLatLng, 14.5),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.my_location_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom sheet ───────────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: 20,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Distance & ETA row
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.straighten_rounded,
                            label: distKm != null
                                ? '${distKm.toStringAsFixed(1)} km'
                                : '— km',
                            color: AppColors.accentBlue,
                          ),
                          const SizedBox(width: 12),
                          _InfoChip(
                            icon: Icons.access_time_rounded,
                            label: etaMin != null ? '~$etaMin min' : '— min',
                            color: AppColors.warningAmber,
                          ),
                          const SizedBox(width: 12),
                          _InfoChip(
                            icon: Icons.location_on_rounded,
                            label:
                                '${sos.latitude.toStringAsFixed(4)}, ${sos.longitude.toStringAsFixed(4)}',
                            color: AppColors.emergency,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Navigate button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openGoogleMaps(sos),
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('Navigate with Google Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Complete button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _completing ? null : () => _complete(sos),
                          icon: _completing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(_completing
                              ? 'Completing...'
                              : '✅ Mission Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.onlineGreen,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompleted() {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.onlineGreen, size: 72),
              const SizedBox(height: 20),
              const Text('SOS Resolved!',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Great work! The customer has been helped.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.go('/driver/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Customer location marker (red pulsing) ────────────────────────────────────
class _CustomerMarker extends StatefulWidget {
  @override
  State<_CustomerMarker> createState() => _CustomerMarkerState();
}

class _CustomerMarkerState extends State<_CustomerMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
        CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.emergency,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.emergency.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.person_pin_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
