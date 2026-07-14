// lib/router.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

import 'config.dart'; // Ensure this points to where AppConfig.baseUrl is stored

// Screens
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

// Web Screens
import 'screens/web_pages/landing_screen.dart';
import 'screens/web_pages/verification_screen.dart';
import 'screens/web_pages/reset_password_screen.dart';

// Services
import 'services/auth_service.dart';

// Global Keys used for Context-less Navigation
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> homeNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> chatNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> updatesNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> directoryNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> profileNavKey = GlobalKey<NavigatorState>();

// ✅ HELPER: Compares current version against the required minimum version
bool isUpdateRequired(String currentVersion, String minRequiredVersion) {
  try {
    List<int> currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> minParts = minRequiredVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < minParts.length; i++) {
      int currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (currentPart < minParts[i]) return true; // Update required!
      if (currentPart > minParts[i]) return false; // Version is newer than required
    }
  } catch (e) {
    debugPrint("Version parsing error: $e");
    return false;
  }
  return false;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  
  initialLocation: '/',
  
  redirect: (context, state) {
    if (kIsWeb) {
      final String fragment = Uri.base.fragment; 
      if (fragment.startsWith('/')) {
        if (state.uri.path == '/' || state.uri.path == '/landing') {
          return fragment; 
        }
      }
    }
    return null; 
  },

  routes: [
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

    // ✅ FIX: Version Check & Auth Gatekeeper
    GoRoute(
      path: '/',
      builder: (context, state) {
        return FutureBuilder<Map<String, dynamic>>(
          future: () async {
            bool needsUpdate = false;
            
            // 1. Check for Forced Updates (Skip on Web)
            if (!kIsWeb) {
              try {
                final packageInfo = await PackageInfo.fromPlatform();
                final currentVersion = packageInfo.version;
                
                final response = await http.get(Uri.parse('${AppConfig.baseUrl}/api/config/version'))
                    .timeout(const Duration(seconds: 5));
                
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  final minVersion = data['min_version'];
                  needsUpdate = isUpdateRequired(currentVersion, minVersion);
                }
              } catch (e) {
                debugPrint("App version check failed (Network or Server): $e");
              }
            }

            // 2. Check Standard Auth & Permissions
            final sessionValid = await AuthService().isSessionValid();
            final prefs = await SharedPreferences.getInstance();
            final hasSeen = prefs.getBool('has_seen_notification_prompt') ?? false;
            
            return {
              'needsUpdate': needsUpdate,
              'sessionValid': sessionValid, 
              'hasSeen': hasSeen
            };
          }(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
            }
            
            final needsUpdate = snapshot.data?['needsUpdate'] == true;
            final isLoggedIn = snapshot.data?['sessionValid'] == true;
            final hasSeen = snapshot.data?['hasSeen'] == true;
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Priority 1: Force Update
              if (needsUpdate) {
                 final storeUrl = defaultTargetPlatform == TargetPlatform.iOS 
                     ? "https://apps.apple.com/app/idYOUR_APP_ID" // Replace with your iOS App ID
                     : "https://play.google.com/store/apps/details?id=com.ascon.app";
                 context.go('/update', extra: storeUrl);
                 return;
              }

              // Priority 2: Standard Routing
              if (isLoggedIn) {
                context.go('/home');
              } else if (kIsWeb) {
                context.go('/landing');
              } else {
                if (!hasSeen) {
                  context.go('/notification_permission', extra: '/login');
                } else {
                  context.go('/login');
                }
              }
            });

            return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
          },
        );
      },
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