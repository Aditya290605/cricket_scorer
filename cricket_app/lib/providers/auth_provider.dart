import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  String? _errorMessage;
  bool _isSigningUp = false; // Flag to prevent race condition during signup

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _status = AuthStatus.loading;
    notifyListeners();

    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) async {
      // Skip if we're in the middle of signing up (to avoid race condition)
      if (_isSigningUp) return;

      if (user != null) {
        // User is signed in, fetch user data from Firestore
        await _fetchUserData(user.uid);
      } else {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserData(String uid, {bool forceServer = false}) async {
    try {
      // Cancel existing subscription if any
      await _userSubscription?.cancel();

      // Subscribe to user document changes
      _userSubscription =
          _firestore.collection('users').doc(uid).snapshots().listen((doc) {
        if (doc.exists) {
          _currentUser = AppUser.fromMap(doc.data()!);
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
        notifyListeners();
      }, onError: (e) {
        debugPrint('Error listening to user data: $e');
        _status = AuthStatus.error;
        _errorMessage = 'Failed to load user data';
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error setting up user stream: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Failed to load user data';
      notifyListeners();
    }
  }

  // Sign up with email
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String playerType,
  }) async {
    try {
      _isSigningUp = true; // Set flag to prevent auth listener interference
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      // Create Firebase Auth account
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        _isSigningUp = false;
        throw Exception('Failed to create account');
      }

      // Skip updateDisplayName - causes PigeonUserDetails bug in some firebase_auth versions
      // Name is stored in Firestore user document instead

      // Generate unique UUID for friend system
      final uuid = credential.user!.uid;

      // Create user document in Firestore
      final newUser = AppUser(
        uuid: uuid,
        email: email,
        name: name,
        playerType: playerType,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uuid).set(newUser.toMap());

      // Also create/link a player document
      await _createPlayerRecord(uuid, name, playerType);

      _currentUser = newUser;
      _status = AuthStatus.authenticated;
      _isSigningUp = false; // Reset flag
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isSigningUp = false; // Reset flag
      _status = AuthStatus.error;
      _errorMessage = _getAuthErrorMessage(e.code);
      debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _isSigningUp = false; // Reset flag
      _status = AuthStatus.error;
      _errorMessage = 'Signup failed: ${e.toString()}';
      debugPrint('Signup error: $e');
      notifyListeners();
      return false;
    }
  }

  // Sign in with email
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Failed to sign in');
      }

      await _fetchUserData(credential.user!.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getAuthErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      notifyListeners();

      final credential = await _authService.signInWithGoogle();

      if (credential == null || credential.user == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      final user = credential.user!;

      // Check if user exists in Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        // New user - create user document
        final newUser = AppUser(
          uuid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Player',
          playerType: 'allrounder', // Default for Google sign-in
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        await _createPlayerRecord(user.uid, newUser.name, 'allrounder');
        _currentUser = newUser;
      } else {
        _currentUser = AppUser.fromMap(doc.data()!);
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Google sign-in failed: $e';
      notifyListeners();
      return false;
    }
  }

  // Create player record linked to user
  Future<void> _createPlayerRecord(
      String uuid, String name, String playerType) async {
    try {
      // Check if player already exists with this name
      final existingPlayer = await _firestore
          .collection('players')
          .where('playerName', isEqualTo: name)
          .limit(1)
          .get();

      if (existingPlayer.docs.isNotEmpty) {
        // Link existing player to user
        await _firestore
            .collection('players')
            .doc(existingPlayer.docs.first.id)
            .update({
          'userUuid': uuid,
        });

        // Update user with linked player ID
        await _firestore.collection('users').doc(uuid).update({
          'linkedPlayerId': existingPlayer.docs.first.id,
        });
      } else {
        // Create new player
        final playerId = const Uuid().v4();
        await _firestore.collection('players').doc(playerId).set({
          'playerId': playerId,
          'playerName': name,
          'userUuid': uuid,
          'team': '',
          'totalRuns': 0,
          'sixes': 0,
          'fours': 0,
          'overs': 0.0,
          'wickets': 0,
          'ballsFaced': 0,
          'role': playerType,
        });

        // Update user with linked player ID
        await _firestore.collection('users').doc(uuid).update({
          'linkedPlayerId': playerId,
        });
      }
    } catch (e) {
      debugPrint('Error creating player record: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _userSubscription?.cancel();
      _userSubscription = null;
      await _authService.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send reset email';
      notifyListeners();
      return false;
    }
  }

  // Search users by name for adding friends
  Future<List<AppUser>> searchUsersByName(String query) async {
    if (query.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .where((user) => user.uuid != _currentUser?.uuid) // Exclude self
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String toUuid) async {
    if (_currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Add to sender's sent requests
      batch.update(_firestore.collection('users').doc(_currentUser!.uuid), {
        'friendRequestsSent': FieldValue.arrayUnion([toUuid]),
      });

      // Add to receiver's received requests
      batch.update(_firestore.collection('users').doc(toUuid), {
        'friendRequestsReceived': FieldValue.arrayUnion([_currentUser!.uuid]),
      });

      await batch.commit();

      // Update local user
      _currentUser = _currentUser!.copyWith(
        friendRequestsSent: [..._currentUser!.friendRequestsSent, toUuid],
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return false;
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String fromUuid) async {
    if (_currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Add each other as friends
      batch.update(_firestore.collection('users').doc(_currentUser!.uuid), {
        'friends': FieldValue.arrayUnion([fromUuid]),
        'friendRequestsReceived': FieldValue.arrayRemove([fromUuid]),
      });

      batch.update(_firestore.collection('users').doc(fromUuid), {
        'friends': FieldValue.arrayUnion([_currentUser!.uuid]),
        'friendRequestsSent': FieldValue.arrayRemove([_currentUser!.uuid]),
      });

      await batch.commit();

      // Update local user
      _currentUser = _currentUser!.copyWith(
        friends: [..._currentUser!.friends, fromUuid],
        friendRequestsReceived: _currentUser!.friendRequestsReceived
            .where((id) => id != fromUuid)
            .toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      return false;
    }
  }

  // Reject friend request
  Future<bool> rejectFriendRequest(String fromUuid) async {
    if (_currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      batch.update(_firestore.collection('users').doc(_currentUser!.uuid), {
        'friendRequestsReceived': FieldValue.arrayRemove([fromUuid]),
      });

      batch.update(_firestore.collection('users').doc(fromUuid), {
        'friendRequestsSent': FieldValue.arrayRemove([_currentUser!.uuid]),
      });

      await batch.commit();

      // Update local user
      _currentUser = _currentUser!.copyWith(
        friendRequestsReceived: _currentUser!.friendRequestsReceived
            .where((id) => id != fromUuid)
            .toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
      return false;
    }
  }

  // Delete friend
  Future<bool> deleteFriend(String friendId) async {
    if (_currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Remove friend from current user's friend list
      batch.update(_firestore.collection('users').doc(_currentUser!.uuid), {
        'friends': FieldValue.arrayRemove([friendId]),
      });

      // Remove current user from friend's friend list
      batch.update(_firestore.collection('users').doc(friendId), {
        'friends': FieldValue.arrayRemove([_currentUser!.uuid]),
      });

      await batch.commit();

      // Update local user
      _currentUser = _currentUser!.copyWith(
        friends: _currentUser!.friends.where((id) => id != friendId).toList(),
      );
      notifyListeners();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting friend: $e');
      return false;
    }
  }

  // Update profile
  Future<bool> updateProfile({
    required String name,
    required String playerType,
  }) async {
    if (_currentUser == null) return false;

    try {
      final batch = _firestore.batch();

      // Update user document
      batch.update(_firestore.collection('users').doc(_currentUser!.uuid), {
        'name': name,
        'playerType': playerType,
      });

      // Update linked player document if exists
      if (_currentUser!.linkedPlayerId != null) {
        batch.update(
            _firestore.collection('players').doc(_currentUser!.linkedPlayerId),
            {
              'playerName': name,
              'role': playerType,
            });
      }

      await batch.commit();

      // Update local user
      _currentUser = _currentUser!.copyWith(
        name: name,
        playerType: playerType,
      );

      // Attempt to update Firebase Auth display name as well
      await _authService.updateDisplayName(name);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // Get friend details
  Future<List<AppUser>> getFriends() async {
    if (_currentUser == null || _currentUser!.friends.isEmpty) return [];

    try {
      final friends = <AppUser>[];
      for (final friendId in _currentUser!.friends) {
        final doc = await _firestore.collection('users').doc(friendId).get();
        if (doc.exists) {
          friends.add(AppUser.fromMap(doc.data()!));
        }
      }
      return friends;
    } catch (e) {
      debugPrint('Error getting friends: $e');
      return [];
    }
  }

  // Get friend requests
  Future<List<AppUser>> getFriendRequests() async {
    if (_currentUser == null || _currentUser!.friendRequestsReceived.isEmpty) {
      return [];
    }

    try {
      final requests = <AppUser>[];
      for (final userId in _currentUser!.friendRequestsReceived) {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          requests.add(AppUser.fromMap(doc.data()!));
        }
      }
      return requests;
    } catch (e) {
      debugPrint('Error getting friend requests: $e');
      return [];
    }
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_authService.currentUser != null) {
      await _fetchUserData(_authService.currentUser!.uid, forceServer: true);
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
