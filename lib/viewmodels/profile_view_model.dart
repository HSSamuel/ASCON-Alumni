import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

class ProfileState {
  final Map<String, dynamic>? userProfile;
  final bool isLoading;
  final bool isOnline;
  final String? lastSeen;
  final double completionPercent;

  const ProfileState({
    this.userProfile,
    this.isLoading = false, 
    this.isOnline = false,
    this.lastSeen,
    this.completionPercent = 0.0,
  });

  ProfileState copyWith({
    Map<String, dynamic>? userProfile,
    bool? isLoading,
    bool? isOnline,
    String? lastSeen,
    double? completionPercent,
  }) {
    return ProfileState(
      userProfile: userProfile ?? this.userProfile,
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      completionPercent: completionPercent ?? this.completionPercent,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  final Box _cacheBox = Hive.box('ascon_cache');
  
  Timer? _presenceTimer; 

  ProfileNotifier() : super(const ProfileState()) {
    loadProfile();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    SocketService().socket?.off('user_status_result', _handleDirectPresenceUpdate);
    SocketService().socket?.off('user_status_update', _handleDirectPresenceUpdate);
    super.dispose();
  }

  Future<void> loadProfile({bool isRefresh = false, bool showSkeleton = false}) async {
    const String cacheKey = 'user_profile_cache';

    if (showSkeleton && mounted) {
      state = state.copyWith(isLoading: true);
    }

    if (!isRefresh && !showSkeleton) {
      final String? cachedProfileStr = _cacheBox.get(cacheKey);
      if (cachedProfileStr != null) {
        try {
          final Map<String, dynamic> cachedProfile = jsonDecode(cachedProfileStr);
          if (mounted) {
            state = state.copyWith(
              userProfile: cachedProfile,
              isLoading: false,
              isOnline: cachedProfile['isOnline'] == true,
              lastSeen: cachedProfile['lastSeen']?.toString(),
              completionPercent: _calculateCompletion(cachedProfile),
            );
          }
          if (cachedProfile['_id'] != null) {
            _listenToSocket(cachedProfile['_id']);
          }
        } catch (e) {
          debugPrint("Profile Cache read error: $e");
        }
      } else {
        if (mounted) state = state.copyWith(isLoading: true);
      }
    }

    try {
      final profile = await _dataService.fetchProfile();
      
      // ✅ FIX: Instantly exit if the user closed the screen while loading
      if (!mounted) return; 
      
      if (profile != null) {
        bool isOnline = profile['isOnline'] == true;
        String? lastSeen = profile['lastSeen']?.toString();
        final percent = _calculateCompletion(profile);

        await _cacheBox.put(cacheKey, jsonEncode(profile));

        // 🛡️ THE "SELF-PRESENCE" PARADOX FIX 🛡️
        // ✅ FIX 1: Check userId before _id so it properly matches Auth ID
        final targetUserId = profile['userId'] ?? profile['_id'];
        final myId = SocketService().currentUserId;

        if (myId != null && targetUserId == myId) {
          // If it's MY profile, ignore the database. My physical connection is the source of truth.
          final isPhysicallyConnected = SocketService().socket?.connected == true;
          isOnline = isPhysicallyConnected;
          // ✅ FIX 2: Generate valid ISO date string instead of 'Just now' to prevent parsing crash
          lastSeen = isPhysicallyConnected ? null : DateTime.now().toIso8601String();
        } else {
          // The standard Stale Data Guard for checking OTHER users
          if (state.isOnline && !isOnline) {
            isOnline = true;
            lastSeen = null;
          }
        }

        state = state.copyWith(
          userProfile: profile,
          isLoading: false,
          isOnline: isOnline,
          lastSeen: lastSeen,
          completionPercent: percent
        );
        
        if (profile['_id'] != null) {
          _listenToSocket(profile['_id']);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint("Network fetch failed, relying on cache: $e");
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void _handleDirectPresenceUpdate(dynamic data) {
    if (!mounted || data == null) return;
    
    // ✅ FIX 1: Check userId before _id
    final targetUserId = state.userProfile?['userId'] ?? state.userProfile?['_id'];
    
    if (targetUserId != null && data['userId'] == targetUserId) {
      bool incomingOnline = data['isOnline'] == true;
      String? incomingLastSeen = incomingOnline ? null : data['lastSeen']?.toString();

      // 🛡️ THE "SELF-PRESENCE" PARADOX FIX (Socket Broadcasts) 🛡️
      final myId = SocketService().currentUserId;
      if (targetUserId == myId) {
        final isPhysicallyConnected = SocketService().socket?.connected == true;
        incomingOnline = isPhysicallyConnected;
        // ✅ FIX 2: Generate valid ISO date string
        incomingLastSeen = isPhysicallyConnected ? null : DateTime.now().toIso8601String();
      }

      state = state.copyWith(
        isOnline: incomingOnline,
        lastSeen: incomingLastSeen
      );
    }
  }

  void refreshPresence() {
    // ✅ FIX 1: Check userId before _id
    final targetUserId = state.userProfile?['userId'] ?? state.userProfile?['_id'];
    if (targetUserId != null) {
      _requestPresence(targetUserId);
    }
  }

  void _requestPresence(String userId) {
    try {
      SocketService().checkUserStatus(userId);
      SocketService().socket?.emit('check_user_status', {'userId': userId});
    } catch (e) {
      debugPrint("Profile presence request error: $e");
    }
  }

  void _listenToSocket(String? userId) {
    if (userId == null) return;

    // ✅ FIX: Remove old listeners to prevent multi-firing on pull-to-refresh
    SocketService().socket?.off('user_status_result', _handleDirectPresenceUpdate);
    SocketService().socket?.off('user_status_update', _handleDirectPresenceUpdate);

    final myId = SocketService().currentUserId;

    // ✅ FIX: Only start the 10-second spam timer if we are looking at SOMEONE ELSE.
    if (userId != myId) {
      _requestPresence(userId);
      _presenceTimer?.cancel();
      _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _requestPresence(userId);
      });
    } else {
      // If it is ME, kill the timer entirely. The server no longer gets to tell me if I am online!
      _presenceTimer?.cancel();
    }

    SocketService().socket?.on('user_status_result', _handleDirectPresenceUpdate);
    SocketService().socket?.on('user_status_update', _handleDirectPresenceUpdate);
  }

  double _calculateCompletion(Map<String, dynamic> data) {
    int total = 5; 
    int filled = 0;
    
    if (data['profilePicture'] != null && data['profilePicture'].toString().isNotEmpty) filled++;
    if (data['jobTitle'] != null && data['jobTitle'].toString().isNotEmpty) filled++;
    if (data['organization'] != null && data['organization'].toString().isNotEmpty) filled++;
    if (data['bio'] != null && data['bio'].toString().isNotEmpty) filled++;
    if (data['yearOfAttendance'] != null && data['yearOfAttendance'].toString().isNotEmpty) filled++;
    
    return filled / total;
  }

  Future<void> logout() async {
    SocketService().logoutUser();
    await _authService.logout();
  }
}

final profileProvider = StateNotifierProvider.autoDispose<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});