import 'dart:async'; 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; 
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; 
import 'package:flutter_callkit_incoming/entities/entities.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

import 'widgets/web_download_banner.dart';
import 'services/notification_service.dart';
import 'services/socket_service.dart'; 
import 'services/auth_service.dart'; 
import 'config/theme.dart';
import 'config.dart';
import 'router.dart'; 
import 'utils/error_handler.dart'; 

final GlobalKey<NavigatorState> navigatorKey = rootNavigatorKey;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ProviderContainer providerContainer = ProviderContainer();

Map<String, dynamic>? pendingDeepLink;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); 
  await dotenv.load(fileName: "env.txt"); 

  if (kIsWeb) return;

  final type = message.data['type'];
  final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  final silentSystemEvents = ['call_ended', 'call_rejected', 'silent_sync', 'login_sync', 'sync', 'heartbeat'];
  if (silentSystemEvents.contains(type)) {
    if (type == 'call_ended' || type == 'call_rejected') {
      final String? uuid = message.data['channelName'] ?? message.data['id'];
      if (uuid != null) {
        await FlutterCallkitIncoming.endCall(uuid);
      }
    }
    return;
  }

  if ((type == 'incoming_call' || type == 'call_offer' || type == 'video_call') && isForeground) {
    return;
  }

  if (type == 'chat_message') {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingChatsJson = prefs.getStringList('pending_background_chats') ?? [];
      pendingChatsJson.add(jsonEncode(message.data));
      await prefs.setStringList('pending_background_chats', pendingChatsJson);
    } catch(e) {
      debugPrint("Pre-emptive SharedPreferences cache error: $e");
    }

    final String? messageId = message.data['messageId'];
    if (messageId != null) {
      const storage = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
      String? token = await storage.read(key: 'auth_token');
      
      if (token != null) {
        try {
          await http.put(
            Uri.parse('${AppConfig.baseUrl}/api/chat/message/$messageId/delivered'),
            headers: {'auth-token': token},
          );
        } catch (e) {
          debugPrint("Delivery receipt failed: $e");
        }
      }
    }
  }

  if (type == 'incoming_call' || type == 'call_offer' || type == 'video_call') {
    CallKitParams callKitParams = CallKitParams(
      id: message.data['channelName'] ?? "call_${DateTime.now().millisecondsSinceEpoch}", 
      nameCaller: message.data['callerName'] ?? 'Alumni User',
      appName: 'ASCON Connect',
      avatar: message.data['callerAvatar'] ?? '',
      handle: 'Incoming Call',
      type: (message.data['isVideoCall'] == "true" || type == 'video_call') ? 1 : 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000, 
      extra: <String, dynamic>{
        'channelName': message.data['channelName'],
        'callerId': message.data['callerId'],
        'callerAvatar': message.data['callerAvatar'] 
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0F3621',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'CallKitIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  } 
  else if (message.notification == null && message.data.isNotEmpty) {
    if (message.data['title'] == null && message.data['body'] == null && type != 'chat_message') {
      return; 
    }

    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground, 
    );

    String title = message.data['title'] ?? "New Notification";
    String body = message.data['body'] ?? "You have a new update";
    String? imageUrl = message.data['image'] ?? message.data['profilePicture'];

    ByteArrayAndroidBitmap? largeIcon;
    StyleInformation? styleInfo;

    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http') && !imageUrl.contains('default-user')) {
      try {
        final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          largeIcon = ByteArrayAndroidBitmap(response.bodyBytes);
          
          if (type == 'chat_message') {
            styleInfo = BigTextStyleInformation(
              body,
              contentTitle: title,
              htmlFormatContentTitle: true,
              htmlFormatBigText: true,
            );
          } else {
            styleInfo = BigPictureStyleInformation(largeIcon, largeIcon: largeIcon, contentTitle: title, summaryText: body, htmlFormatContentTitle: true, htmlFormatSummaryText: true);
          }
        }
      } catch (e) {
        debugPrint("Bg Image download failed: $e");
      }
    }

    if (styleInfo == null && type == 'chat_message') {
       styleInfo = BigTextStyleInformation(
         body,
         contentTitle: title,
         htmlFormatContentTitle: true,
         htmlFormatBigText: true,
       );
    }

    List<AndroidNotificationAction> actions = [];
    if (type == 'chat_message') {
      actions = [
        const AndroidNotificationAction(
          'REPLY_ACTION', 'Reply', allowGeneratedReplies: true, showsUserInterface: false, 
          inputs: [AndroidNotificationActionInput(label: 'Type a message...')]
        ),
        const AndroidNotificationAction('MARK_READ_ACTION', 'Mark as Read', showsUserInterface: false),
      ];
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      channelDescription: AppConfig.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF1B5E3A),
      icon: 'ic_notification',
      largeIcon: largeIcon,
      styleInformation: styleInfo,
      actions: actions,
      enableVibration: true,
      playSound: true, 
    );

    await localNotifications.show(
      message.hashCode.abs(),
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }
}

void main() async {
  ErrorHandler.init();

  var defaultDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      if (message.contains("GSI_LOGGER")) return;
      if (message.contains("access_token")) return;
    }
    defaultDebugPrint(message, wrapWidth: wrapWidth);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    usePathUrlStrategy();
    
    await dotenv.load(fileName: "env.txt");
    await Hive.initFlutter();
    await Hive.openBox('ascon_cache');
    
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString('bg_api_url', AppConfig.baseUrl);
    } catch (e) {
      debugPrint("Failed to cache background API URL: $e");
    }
    
    bool hasValidSession = await AuthService().isSessionValid();
    if (hasValidSession) {
      SocketService().initSocket();
    }

    bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);

    if (kIsWeb || isMobile || isDesktop) {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConfig.firebaseWebApiKey, 
            authDomain: AppConfig.firebaseWebAuthDomain,
            projectId: AppConfig.firebaseWebProjectId,
            storageBucket: AppConfig.firebaseWebStorageBucket,
            messagingSenderId: AppConfig.firebaseWebMessagingSenderId,
            appId: AppConfig.firebaseWebAppId,
            measurementId: AppConfig.firebaseWebMeasurementId,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }

    FlutterError.onError = (errorDetails) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      } else {
        debugPrint("Flutter Error (Web): ${errorDetails.exception}");
      }
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint("Platform Error (Web): $error\n$stack");
      }
      return true;
    };

    if (isMobile) {
       FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    runApp(UncontrolledProviderScope(
      container: providerContainer, 
      child: const MyApp()
    ));
    
  }, (error, stack) {
    debugPrint("🔴 Uncaught Zone Error: $error\n$stack");
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription? _callSubscription;
  static bool _isNavigatingToCall = false;
  Timer? _offlineGracePeriodTimer; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _listenForIncomingCalls();
    _listenForCallKitEvents(); 
    _setupInteractedMessage();
    _triggerColdStartSync();
    _checkActiveCallsOnColdStart(); 
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _callSubscription?.cancel();
    _offlineGracePeriodTimer?.cancel();
    super.dispose();
  }

  Future<void> _ingestBackgroundMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingChatsJson = prefs.getStringList('pending_background_chats') ?? [];
      
      if (pendingChatsJson.isNotEmpty) {
        var chatBox = Hive.isBoxOpen('ascon_cache') 
            ? Hive.box('ascon_cache') 
            : await Hive.openBox('ascon_cache');
            
        List<dynamic> existingChats = chatBox.get('pending_background_chats', defaultValue: []);
        
        for (String jsonStr in pendingChatsJson) {
          existingChats.add(jsonDecode(jsonStr));
        }
        
        await chatBox.put('pending_background_chats', existingChats);
        await prefs.remove('pending_background_chats'); 
      }
    } catch (e) {
      debugPrint("Error ingesting background messages: $e");
    }
  }

  Future<void> _checkActiveCallsOnColdStart() async {
    if (kIsWeb) return;
    try {
      final activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is List && activeCalls.isNotEmpty) {
        final call = activeCalls[0];
        final data = call['extra'];
        
        if (data == null) return;

        final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;

        if (currentPath == '/') {
          pendingDeepLink = {
            'type': call['type'] == 1 ? 'video_call' : 'incoming_call',
            'callerName': call['nameCaller'] ?? "Alumni User",
            'callerId': data['callerId'] ?? "",
            'channelName': data['channelName'] ?? call['id'] ?? "",
            'callerAvatar': data['callerAvatar'] ?? call['avatar'] ?? "",
            'isGroupCall': data['isGroupCall'] == 'true' || data['isGroupCall'] == true,
            'isVideoCall': call['type'] == 1,
          };
          return;
        }

        if (_isNavigatingToCall) return; 
        _isNavigatingToCall = true;
        appRouter.push('/call', extra: {
          'isGroupCall': data['isGroupCall'] == 'true' || data['isGroupCall'] == true,
          'isVideoCall': call['type'] == 1,
          'remoteName': call['nameCaller'] ?? "Alumni User",
          'remoteId': data['callerId'] ?? "",
          'channelName': data['channelName'] ?? call['id'] ?? "",
          'remoteAvatar': data['callerAvatar'] ?? call['avatar'] ?? "",
          'isIncoming': true,
          'autoAccept': true,
        }).then((_) => _isNavigatingToCall = false);
      }
    } catch (e) {
      debugPrint("Cold start CallKit check failed: $e");
    }
  }

  Future<void> _triggerColdStartSync() async {
    await _ingestBackgroundMessages();

    if (await AuthService().isSessionValid()) {
      await NotificationService().init();
      AuthService().performGlobalSilentSync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _offlineGracePeriodTimer = Timer(const Duration(seconds: 4), () {
        try {
          SocketService().socket?.emit('go_offline');
          Future.delayed(const Duration(milliseconds: 100), () {
            SocketService().disconnect(); 
          });
        } catch (e) {
          debugPrint("Offline emit failed: $e");
        }
      });
    } 
    else if (state == AppLifecycleState.resumed) {
      _ingestBackgroundMessages();

      if (_offlineGracePeriodTimer != null && _offlineGracePeriodTimer!.isActive) {
        _offlineGracePeriodTimer!.cancel();
      } else {
        AuthService().isSessionValid().then((isValid) {
          if (isValid) {
            SocketService().initSocket(); 
            SocketService().socket?.emit('go_online'); 
            AuthService().performGlobalSilentSync();
          }
        });
      }
    }
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
  }

  void _handleNotificationClick(RemoteMessage message) {
    final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
    
    if (currentPath == '/') {
      pendingDeepLink = message.data;
    } else {
      _executeDeepLink(message.data); 
    }
  }

  void _executeDeepLink(Map<String, dynamic> data) async {
    if (data['type'] == 'incoming_call' || data['type'] == 'video_call') {
      if (_isNavigatingToCall) return; 
      _isNavigatingToCall = true;

      final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
      if (currentRoute.contains('/call')) return;

      final userMap = await AuthService().getCachedUser();
      final currentUserName = userMap?['fullName'] ?? "Alumni User";
      final currentUserAvatar = userMap?['profilePicture'];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.push('/call', extra: {
          'isGroupCall': data['isGroupCall'] == 'true' || data['isGroupCall'] == true,
          'isVideoCall': data['isVideoCall'] == 'true' || data['isVideoCall'] == true,
          'remoteName': data['callerName'] ?? data['groupName'] ?? "Alumni User",
          'remoteId': data['callerId'] ?? "",
          'channelName': data['channelName'] ?? "",
          'remoteAvatar': data['callerAvatar'] ?? data['callerPic'], 
          'isIncoming': true,
          'currentUserName': currentUserName,
          'currentUserAvatar': currentUserAvatar,
        }).then((_) => _isNavigatingToCall = false);
      });
    } 
    else {
      NotificationService().handleNavigation(data);
    }
  }

  void _listenForCallKitEvents() {
    if (kIsWeb) return;
    FlutterCallkitIncoming.onEvent.listen((event) async { 
      switch (event!.event) {
        case Event.actionCallAccept:
          final data = event.body;
          String channelName = data['extra']?['channelName'] ?? data['id'] ?? "";
          String callerId = data['extra']?['callerId'] ?? "";
          String callerAvatar = data['extra']?['callerAvatar'] ?? data['avatar'] ?? ""; 

          final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;

          if (currentPath == '/') {
            pendingDeepLink = {
              'type': data['type'] == 1 ? 'video_call' : 'incoming_call',
              'callerName': data['nameCaller'] ?? "Alumni User",
              'callerId': callerId,
              'channelName': channelName,
              'callerAvatar': callerAvatar,
              'isGroupCall': data['extra']?['isGroupCall'] == 'true' || data['extra']?['isGroupCall'] == true,
              'isVideoCall': data['type'] == 1,
            };
            return;
          }

          if (_isNavigatingToCall) return; 
          _isNavigatingToCall = true;

          final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.toString();
          if (currentRoute.contains('/call')) return;

          final userMap = await AuthService().getCachedUser();
          final currentUserName = userMap?['fullName'] ?? "Alumni User";
          final currentUserAvatar = userMap?['profilePicture'];

          appRouter.push('/call', extra: {
            'isGroupCall': false, 
            'isVideoCall': data['type'] == 1,
            'remoteName': data['nameCaller'] ?? "Alumni User",
            'remoteId': callerId,
            'channelName': channelName,
            'remoteAvatar': callerAvatar, 
            'isIncoming': true,
            'autoAccept': true,
            'currentUserName': currentUserName,
            'currentUserAvatar': currentUserAvatar,
          }).then((_) => _isNavigatingToCall = false);
          break;
          
        case Event.actionCallDecline:
          SocketService().socket?.emit('reject_call', {'reason': 'user_busy'});
          break;
          
        default:
          break;
      }
    });
  }

  void _listenForIncomingCalls() {
    _callSubscription = SocketService().callEvents.listen((event) async {
      if (event['type'] == 'incoming') {
        final data = event['data'];
        
        bool isGroup = data['callerData']?['isGroupCall'] ?? false;
        String displayRemoteName = isGroup 
            ? (data['callerData']?['groupName'] ?? "Group Call") 
            : (data['callerData']?['callerName'] ?? "Alumni User");

        final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
        
        final isAuthScreen = currentPath == '/' || currentPath == '/login';
        final isAlreadyInCall = currentPath == '/call';

        if (isAlreadyInCall) {
          SocketService().socket?.emit('reject_call', {
            'targetUserId': data['callerId'],
            'reason': 'user_busy'
          });
          return;
        }

        if (!isAuthScreen) {
          final userMap = await AuthService().getCachedUser();
          final currentUserName = userMap?['fullName'] ?? "Alumni User";
          final currentUserAvatar = userMap?['profilePicture'];

          final callArgs = {
            'isGroupCall': isGroup, 
            'isVideoCall': data['callerData']?['isVideoCall'] ?? false, 
            'remoteName': displayRemoteName,
            'remoteId': data['callerId'] ?? "", 
            'channelName': data['channelName'] ?? "",
            'remoteAvatar': data['callerData']?['callerAvatar'], 
            'isIncoming': true, 
            'currentUserName': currentUserName,
            'currentUserAvatar': currentUserAvatar,
          };

          if (kIsWeb) {
            _showWebCallBanner(callArgs);
          } else {
            if (_isNavigatingToCall) return; 
            _isNavigatingToCall = true;

            appRouter.push('/call', extra: callArgs).then((_) => _isNavigatingToCall = false);
          }
        }
      }
    });
  }

  void _showWebCallBanner(Map<String, dynamic> callArgs) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        // ✅ Detect screen width for responsiveness
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 400;

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                // ✅ Reduced margins and padding for small screens
                margin: EdgeInsets.only(top: 16, left: isSmallScreen ? 8 : 16, right: isSmallScreen ? 8 : 16),
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2), 
                      blurRadius: 20, 
                      offset: const Offset(0, 10)
                    )
                  ]
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      // ✅ Shrunk avatar size on mobile
                      radius: isSmallScreen ? 20 : 26,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (callArgs['remoteAvatar'] != null && callArgs['remoteAvatar'].toString().isNotEmpty && !callArgs['remoteAvatar'].toString().contains('default-user')) 
                          ? NetworkImage(callArgs['remoteAvatar']) 
                          : null,
                      child: (callArgs['remoteAvatar'] == null || callArgs['remoteAvatar'].toString().isEmpty || callArgs['remoteAvatar'].toString().contains('default-user')) 
                          ? Icon(Icons.person, color: Colors.grey[600], size: isSmallScreen ? 20 : 28) 
                          : null,
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            callArgs['remoteName'], 
                            // ✅ Reduced title font size and added text overflow protection
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 14 : 17),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 2 : 4),
                          Text(
                            callArgs['isVideoCall'] ? "Incoming Video Call..." : "Incoming Voice Call...", 
                            // ✅ Reduced subtitle font size
                            style: TextStyle(color: Theme.of(context).primaryColor, fontSize: isSmallScreen ? 11 : 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        SocketService().socket?.emit('reject_call', {
                          'targetUserId': callArgs['remoteId'],
                          'reason': 'declined'
                        });
                      },
                      child: Container(
                        // ✅ Reduced reject button padding and icon size
                        padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Icon(Icons.call_end, color: Colors.white, size: isSmallScreen ? 18 : 22),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        appRouter.push('/call', extra: callArgs);
                      },
                      child: Container(
                        // ✅ Reduced accept button padding and icon size
                        padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                        decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                        child: Icon(callArgs['isVideoCall'] ? Icons.videocam : Icons.call, color: Colors.white, size: isSmallScreen ? 18 : 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1), 
            end: Offset.zero
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp.router(
          routerConfig: appRouter, 
          title: 'ASCON Alumni',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          // ⚠️ NOTE: The builder wraps the app, meaning the banner is above the Navigator.
          builder: (context, child) {
            return WebDownloadBanner(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}