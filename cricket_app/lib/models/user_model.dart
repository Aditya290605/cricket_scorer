import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uuid;
  final String email;
  final String name;
  final String playerType; // 'bowler', 'batter', 'allrounder'
  final String? photoUrl;
  final List<String> friends;
  final List<String> friendRequestsSent;
  final List<String> friendRequestsReceived;
  final DateTime createdAt;
  final String? linkedPlayerId; // Links to existing players collection

  AppUser({
    required this.uuid,
    required this.email,
    required this.name,
    required this.playerType,
    this.photoUrl,
    this.friends = const [],
    this.friendRequestsSent = const [],
    this.friendRequestsReceived = const [],
    required this.createdAt,
    this.linkedPlayerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'email': email,
      'name': name,
      'playerType': playerType,
      'photoUrl': photoUrl,
      'friends': friends,
      'friendRequestsSent': friendRequestsSent,
      'friendRequestsReceived': friendRequestsReceived,
      'createdAt': Timestamp.fromDate(createdAt),
      'linkedPlayerId': linkedPlayerId,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uuid: map['uuid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      playerType: map['playerType'] ?? 'batter',
      photoUrl: map['photoUrl'],
      friends: List<String>.from(map['friends'] ?? []),
      friendRequestsSent: List<String>.from(map['friendRequestsSent'] ?? []),
      friendRequestsReceived: List<String>.from(map['friendRequestsReceived'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      linkedPlayerId: map['linkedPlayerId'],
    );
  }

  AppUser copyWith({
    String? uuid,
    String? email,
    String? name,
    String? playerType,
    String? photoUrl,
    List<String>? friends,
    List<String>? friendRequestsSent,
    List<String>? friendRequestsReceived,
    DateTime? createdAt,
    String? linkedPlayerId,
  }) {
    return AppUser(
      uuid: uuid ?? this.uuid,
      email: email ?? this.email,
      name: name ?? this.name,
      playerType: playerType ?? this.playerType,
      photoUrl: photoUrl ?? this.photoUrl,
      friends: friends ?? this.friends,
      friendRequestsSent: friendRequestsSent ?? this.friendRequestsSent,
      friendRequestsReceived: friendRequestsReceived ?? this.friendRequestsReceived,
      createdAt: createdAt ?? this.createdAt,
      linkedPlayerId: linkedPlayerId ?? this.linkedPlayerId,
    );
  }
}
