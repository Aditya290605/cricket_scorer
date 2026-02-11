import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_app/models/players.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new player to Firestore
  Future<void> addPlayer(Player player) async {
    try {
      await _firestore
          .collection('players')
          .doc(player.playerId)
          .set(player.toMap());
      if (kDebugMode) {
        debugPrint('Player ${player.playerName} added successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding player: $e');
      }
      rethrow;
    }
  }

  Future<void> updatePlayerTeam(String playerId, String team) async {
    try {
      await _firestore
          .collection('players')
          .doc(playerId)
          .update({'team': team});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating player: $e');
      }
      rethrow;
    }
  }
}
