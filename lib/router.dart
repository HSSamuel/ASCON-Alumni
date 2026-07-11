// lib/router.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:go_router/go_router.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/alumni_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; 
import 'screens/events_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/directory_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/about_screen.dart';
import 'screens/polls_screen.dart';
import 'screens/notification_permission_screen.dart'; 
import 'screens/call_screen.dart'; 
import 'screens/notifications_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/programme_detail_screen.dart';
import 'screens/update_screen.dart'; 

// ✅ Web Screens
import 'screens/web_pages/landing_screen.dart';
import 'screens/web_pages/verification_screen.dart';
import 'screens/web_pages/reset_password_screen.dart';

// Global Keys used for Context-less Navigation
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> homeNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> chatNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> updatesNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> directoryNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> profileNavKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  
  // ✅ FIX 1: Revert to the standard root to prevent GoRouter from overriding direct URLs
  initialLocation: '/',
  
  // ✅ FIX 2: Smart Redirect to catch old links that contain the "#" (e.g., #/verify/...)
  redirect: (context, state) {
    if (kIsWeb) {
      // Grab the raw URL directly from the browser window
      final String fragment = Uri.base.fragment; 
      
      // If the URL contains a legacy hash route (like /verify/... or /reset-password?...)
      if (fragment.startsWith('/')) {
        // Only redirect if the router is trying to stick us on the home/landing page
        if (state.uri.path == '/' || state.uri.path == '/landing') {
          return fragment; // Send them to the actual route hidden inside the hash!
        }
      }
    }
    return null; // Normal routing
  },

  routes: [
    // ==========================================
    // 🌐 WEB-SPECIFIC ROUTES
    // ==========================================
    GoRoute(
      path: '/landing',
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/verify/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return VerificationScreen(id: id);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        return ResetPasswordScreen(token: token);
      },
    ),

    // ==========================================
    // 📱 CORE APP ROUTES
    // ==========================================
    GoRoute(
      path: '/',
      // ✅ FIX 3: Conditionally render the Landing Page (Web) or Splash Screen (Mobile) directly on the root!
      builder: (context, state) => kIsWeb ? const LandingScreen() : const SplashScreen(),
    ),
    
    GoRoute(
      path: '/update',
      builder: (context, state) {
        final storeUrl = state.extra as String? ?? "https://play.google.com/store/apps/details?id=com.ascon.app";
        return UpdateScreen(playStoreUrl: storeUrl);
      },
    ),

    GoRoute(
      path: '/notification_permission',
      builder: (context, state) {
        final nextPath = state.extra as String? ?? '/login';
        return NotificationPermissionScreen(nextPath: nextPath);
      },
    ),

    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/notifications',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const NotificationsScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: homeNavKey, 
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardView(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: chatNavKey,
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatListScreen(), 
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: updatesNavKey, 
          routes: [
            GoRoute(
              path: '/updates',
              builder: (context, state) => const UpdatesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: directoryNavKey, 
          routes: [
            GoRoute(
              path: '/directory',
              builder: (context, state) => const DirectoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: profileNavKey, 
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                final name = state.extra as String?;
                return ProfileScreen(userName: name);
              },
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/events',
      parentNavigatorKey: rootNavigatorKey, 
      builder: (context, state) => const EventsScreen(),
    ),
    
    GoRoute(
      path: '/chat_detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return ChatScreen( 
          conversationId: args['conversationId'],
          receiverId: args['receiverId'],
          receiverName: args['receiverName'],
          receiverProfilePic: args['receiverProfilePic'],
          isOnline: args['isOnline'] ?? false,
          lastSeen: args['lastSeen'],
          isGroup: args['isGroup'] ?? false,
          groupId: args['groupId'],
        );
      },
    ),

    GoRoute(
      path: '/about',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),
    
    GoRoute(
      path: '/polls',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PollsScreen(),
    ),

    GoRoute(
      path: '/call',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return CallScreen(
          isGroupCall: args['isGroupCall'] ?? false,
          isVideoCall: args['isVideoCall'] ?? false,
          remoteName: args['remoteName'] ?? "Unknown",
          remoteId: args['remoteId'] ?? "",
          channelName: args['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}",
          remoteAvatar: args['remoteAvatar'],
          isIncoming: args['isIncoming'] ?? false,
          autoAccept: args['autoAccept'] ?? false,
          currentUserName: args['currentUserName'],     
          currentUserAvatar: args['currentUserAvatar'], 
        );
      },
    ),

    GoRoute(
      path: '/event_detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return EventDetailScreen(eventData: args['eventData']);
      },
    ),

    GoRoute(
      path: '/programme_detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return ProgrammeDetailScreen(programme: args['programme']);
      },
    ),

    GoRoute(
      path: '/alumni_detail',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        
        if (args.containsKey('alumniData') && args['alumniData'] != null) {
          return AlumniDetailScreen(
            alumniData: args['alumniData'] as Map<String, dynamic>,
          );
        }

        final String profileId = args['profileId']?.toString() ?? '';
        final String userId = args['userId']?.toString() ?? args['id']?.toString() ?? '';
        final String fullName = args['fullName']?.toString() ?? 'Alumni';

        final Map<String, dynamic> reconstructedData = {
          '_id': profileId.isNotEmpty ? profileId : userId, 
          'userId': userId,
          'fullName': fullName,
        };
        
        return AlumniDetailScreen(alumniData: reconstructedData);
      },
    ),
  ],
);