class Player {
  final String playerId;
  String playerName;
  String team;
  int totalRuns;
  int sixes;
  int fours;
  double overs;
  int wickets;
  int ballsFaced;
  int matches;
  int runsConceded;
  int totalDismissals;
  int extras;
  String role;
  int ballsBowled;

  Player({
    required this.playerId,
    required this.playerName,
    this.team = '',
    this.totalRuns = 0,
    this.sixes = 0,
    this.fours = 0,
    this.overs = 0.0,
    this.wickets = 0,
    this.ballsFaced = 0,
    this.matches = 0,
    this.runsConceded = 0,
    this.totalDismissals = 0,
    this.extras = 0,
    this.role = 'batsman',
    this.ballsBowled = 0,
  });

  // Calculate strike rate dynamically
  double get strikeRate {
    if (ballsFaced == 0) return 0.0;
    return (totalRuns / ballsFaced) * 100;
  }

  // Convert Player object to Map (JSON) to store in Firebase
  Map<String, dynamic> toMap() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'team': team,
      'totalRuns': totalRuns,
      'sixes': sixes,
      'fours': fours,
      'overs': overs,
      'wickets': wickets,
      'ballsFaced': ballsFaced,
      'matches': matches,
      'runsConceded': runsConceded,
      'totalDismissals': totalDismissals,
      'extras': extras,
      'role': role,
      'ballsBowled': ballsBowled,
      'strikeRate': strikeRate, // optional to store
    };
  }

  // Create Player object from Firebase snapshot (Map)
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
      team: map['team'] ?? '',
      totalRuns: map['totalRuns'] ?? 0,
      sixes: map['sixes'] ?? 0,
      fours: map['fours'] ?? 0,
      overs: (map['overs'] ?? 0.0).toDouble(),
      wickets: map['wickets'] ?? 0,
      ballsFaced: map['ballsFaced'] ?? 0,
      matches: map['matches'] ?? 0,
      runsConceded: map['runsConceded'] ?? 0,
      totalDismissals: map['totalDismissals'] ?? 0,
      extras: map['extras'] ?? 0,
      role: map['role'] ?? 'batsman',
      ballsBowled: map['ballsBowled'] ?? 0,
    );
  }
}
