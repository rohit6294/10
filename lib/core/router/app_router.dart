import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import '../../features/driver/screens/incoming_request_screen.dart';
import '../../features/driver/screens/navigate_to_patient_screen.dart';
import '../../features/driver/screens/patient_picked_up_screen.dart';
import '../../features/driver/screens/navigate_to_hospital_screen.dart';
import '../../features/driver/screens/ride_complete_screen.dart';
import '../../features/hospital/screens/hospital_home_screen.dart';
import '../../features/hospital/screens/incoming_ambulance_screen.dart';
import '../../features/hospital/screens/track_ambulance_screen.dart';
import '../../features/hospital/screens/intake_checklist_screen.dart';
import '../../features/hospital/screens/patient_received_screen.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';

class AppRouter {
  static final _authService = AuthService();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;

      final authRoutes = [
        '/splash',
        '/auth/role',
        '/auth/login/driver',
        '/auth/login/hospital',
        '/auth/register/driver',
        '/auth/register/hospital',
      ];
      final isAuthRoute = authRoutes.contains(location) ||
          location.startsWith('/auth/');

      if (!isLoggedIn && !isAuthRoute) return '/auth/role';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/auth/role',
        builder: (_, __) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/auth/login/:role',
        builder: (_, state) =>
            LoginScreen(role: state.pathParameters['role'] ?? 'driver'),
      ),
      GoRoute(
        path: '/auth/register/:role',
        builder: (_, state) =>
            RegisterScreen(role: state.pathParameters['role'] ?? 'driver'),
      ),

      // ── Driver ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/driver/home',
        builder: (_, __) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/driver/request/:requestId',
        builder: (_, state) => IncomingRequestScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/driver/navigate-patient/:requestId',
        builder: (_, state) => NavigateToPatientScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/driver/pickup-confirm/:requestId',
        builder: (_, state) => PatientPickedUpScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/driver/navigate-hospital/:requestId',
        builder: (_, state) => NavigateToHospitalScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/driver/ride-complete',
        builder: (_, __) => const RideCompleteScreen(),
      ),

      // ── Hospital ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/hospital/home',
        builder: (_, __) => const HospitalHomeScreen(),
      ),
      GoRoute(
        path: '/hospital/ambulance/:requestId',
        builder: (_, state) => IncomingAmbulanceScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/hospital/track/:requestId',
        builder: (_, state) => TrackAmbulanceScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/hospital/checklist/:requestId',
        builder: (_, state) => IntakeChecklistScreen(
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: '/hospital/received',
        builder: (_, __) => const PatientReceivedScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}

// Helper to make GoRouter re-evaluate redirect on auth state change
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
