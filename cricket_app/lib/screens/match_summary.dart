import 'package:clipboard/clipboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cricket_app/screens/starting_screen.dart';
import 'package:cricket_app/services/generate_summary.dart';
import 'package:flutter/material.dart';

// Model classes for static data (to be replaced with Firebase integration)
class Team {
  final String name;
  final int runs;
  final int wickets;
  final double
      overs; // Changed to double for proper cricket overs representation
  final List<PlayerStat> players;

  const Team({
    required this.name,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.players,
  });
}

class PlayerStat {
  final String name;
  final int runs;
  final int ballsFaced;
  final int wickets;
  final int ballsBowled;
  final int runsGiven;
  final bool isMotm; // Man of the Match

  const PlayerStat({
    required this.name,
    this.runs = 0,
    this.ballsFaced = 0,
    this.wickets = 0,
    this.ballsBowled = 0,
    this.runsGiven = 0,
    this.isMotm = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'runs': runs,
      'ballsFaced': ballsFaced,
      'wickets': wickets,
      'ballsBowled': ballsBowled,
      'runsGiven': runsGiven,
      'isMotm': isMotm,
    };
  }
}

class MatchDetails {
  final Team teamA;
  final Team teamB;
  final String venue;
  final String date;
  final String matchSummary;
  final bool teamAWon;
  final String victoryMargin;

  const MatchDetails({
    required this.teamA,
    required this.teamB,
    required this.venue,
    required this.date,
    required this.matchSummary,
    required this.teamAWon,
    required this.victoryMargin,
  });
}

class MatchSummaryScreen extends StatefulWidget {
  final String teamAName;
  final String teamBName;

  final int target;
  final String matchResult;
  final int teamARuns;
  final int teamAWickets;
  final int teamBRuns;
  final int teamBWickets;

  // Match-specific player stats
  final Map<String, dynamic> batsmenStats;
  final Map<String, dynamic> bowlerStats;
  final List<String> teamAPlayers;
  final List<String> teamBPlayers;

  const MatchSummaryScreen({
    super.key,
    required this.teamAName,
    required this.teamBName,
    required this.target,
    required this.matchResult,
    required this.teamARuns,
    required this.teamAWickets,
    required this.teamBRuns,
    required this.teamBWickets,
    required this.batsmenStats,
    required this.bowlerStats,
    required this.teamAPlayers,
    required this.teamBPlayers,
  });

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  late Future<MatchDetails>
      _matchDetailsFuture; // Use Future for async data loading

  final List<PlayerStat> teamAPlayers = [];
  final List<PlayerStat> teamBPlayers = [];
  bool teamAWon = false;

  String? summary;
  bool isLoading = false;

  void _generateSummary() async {
    setState(() => isLoading = true);

    final match = MatchDetails(
      teamA: Team(
        name: widget.teamAName,
        runs: widget.teamARuns,
        wickets: widget.teamAWickets,
        overs: 8,
        players: teamAPlayers, // Add real players
      ),
      teamB: Team(
        name: widget.teamBName,
        runs: widget.teamBRuns,
        wickets: widget.teamBWickets,
        overs: 8,
        players: teamBPlayers, // Add real players
      ),
      venue: 'Ch. Shivaji Ground, Sambhaji Nagar',
      date:
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      matchSummary: widget.matchResult,
      teamAWon: widget.matchResult.contains('team A won'),
      victoryMargin: '${widget.target - widget.teamBRuns} runs',
    );

    final result = await generateDramaticSummary(match);
    debugPrint('${result}');
    setState(() {
      summary = result;
      isLoading = false;
    });
  }

  void _copySummary() {
    if (summary != null) {
      FlutterClipboard.copy(summary!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary copied to clipboard!')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  void _loadMatchDetails() {
    setState(() {
      isLoading = true;
      _matchDetailsFuture = fetchMatchDetailsFromFirebase(
        teamAName: widget.teamAName,
        teamBName: widget.teamBName,
      );

      isLoading = false;
    });
  }

  Future<MatchDetails> fetchMatchDetailsFromFirebase({
    required String teamAName,
    required String teamBName,
  }) async {
    // Use passed match stats instead of fetching from Firebase
    // This ensures we show current match stats, not cumulative career stats

    // Build team A players from match stats
    for (String playerName in widget.teamAPlayers) {
      final batsmanData =
          widget.batsmenStats[playerName] as Map<String, dynamic>?;
      final bowlerData =
          widget.bowlerStats[playerName] as Map<String, dynamic>?;

      // Only add players with stats (played in the match)
      if (batsmanData != null || bowlerData != null) {
        teamAPlayers.add(PlayerStat(
          name: playerName,
          runs: batsmanData?['runs'] ?? 0,
          ballsFaced: batsmanData?['ballsFaced'] ?? 0,
          wickets: bowlerData?['wickets'] ?? 0,
          ballsBowled: bowlerData?['ballsBowled'] ?? 0,
          runsGiven: bowlerData?['runs'] ?? 0,
          isMotm: false, // Can calculate MOTM later
        ));
      }
    }

    // Build team B players from match stats
    for (String playerName in widget.teamBPlayers) {
      final batsmanData =
          widget.batsmenStats[playerName] as Map<String, dynamic>?;
      final bowlerData =
          widget.bowlerStats[playerName] as Map<String, dynamic>?;

      // Only add players with stats (played in the match)
      if (batsmanData != null || bowlerData != null) {
        teamBPlayers.add(PlayerStat(
          name: playerName,
          runs: batsmanData?['runs'] ?? 0,
          ballsFaced: batsmanData?['ballsFaced'] ?? 0,
          wickets: bowlerData?['wickets'] ?? 0,
          ballsBowled: bowlerData?['ballsBowled'] ?? 0,
          runsGiven: bowlerData?['runs'] ?? 0,
          isMotm: false,
        ));
      }
    }

    // Default to 8 overs
    final double teamAOvers = 8.0;
    final double teamBOvers = 8.0;

    final Team teamA = Team(
      name: teamAName,
      runs: widget.teamARuns,
      wickets: widget.teamAWickets,
      overs: teamAOvers,
      players: teamAPlayers,
    );

    final Team teamB = Team(
      name: teamBName,
      runs: widget.teamBRuns,
      wickets: widget.teamBWickets,
      overs: teamBOvers,
      players: teamBPlayers,
    );

    // Determine the winner based on runs
    bool teamAWon = widget.teamARuns > widget.teamBRuns;

    final MatchDetails matchData = MatchDetails(
      teamA: teamA,
      teamB: teamB,
      venue: 'Ch. Shivaji Ground, Sambhaji Nagar',
      date:
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      matchSummary: widget.matchResult,
      teamAWon: teamAWon,
      victoryMargin: widget.matchResult,
    );

    return matchData;
  }

  Future<void> saveMatchDetails(MatchDetails match) async {
    final FirebaseFirestore _db = FirebaseFirestore.instance;

    // Create a new document in 'match_summary' (auto-ID)
    final DocumentReference docRef = _db.collection('match_summary').doc();

    // Prepare match data to store
    final Map<String, dynamic> matchData = {
      'venue': match.venue,
      'date': match.date,
      'timestamp': FieldValue.serverTimestamp(), // For date-based filtering
      'target': widget.target,
      'teamA_run': match.teamA.runs,
      'teamA_wickets': match.teamA.wickets,
      'teamB_run': match.teamB.runs,
      'teamB_wickets': match.teamB.wickets,
      'matchSummary': summary ?? match.matchSummary,
      'teamAWon': match.teamAWon,
      'victoryMargin': match.victoryMargin,
      'teamA_players': teamAPlayers.map((p) => p.name).toList(),
      'teamB_players': teamBPlayers.map((p) => p.name).toList(),
      'teams': {
        'teamA': {
          'name': match.teamA.name,
          'runs': match.teamA.runs,
          'wickets': match.teamA.wickets,
          'overs': match.teamA.overs,
          // Convert overs to balls
          'players': match.teamA.players
              .map((p) => {
                    'name': p.name,
                    'runs': p.runs,
                    'ballsFaced': p.ballsFaced,
                    'wickets': p.wickets,
                    'ballsBowled': p.ballsBowled,
                    'runsGiven': p.runsGiven,
                    'isMotm': p.isMotm,
                  })
              .toList(),
        },
        'teamB': {
          'name': match.teamB.name,
          'runs': match.teamB.runs,
          'wickets': match.teamB.wickets,
          'overs': match.teamB.overs,
          'players': match.teamB.players
              .map((p) => {
                    'name': p.name,
                    'runs': p.runs,
                    'ballsFaced': p.ballsFaced,
                    'wickets': p.wickets,
                    'ballsBowled': p.ballsBowled,
                    'runsGiven': p.runsGiven,
                    'isMotm': p.isMotm,
                  })
              .toList(),
        },
      },
    };

    try {
      // Save the match data
      await docRef.set(matchData);
      debugPrint('Match saved with ID: ${docRef.id}');

      // Get players where 'team' is either teamA or teamB
      final playersQuery = await _db.collection('players').where('team',
          whereIn: [
            match.teamA.name.trim(),
            match.teamB.name.trim()
          ]).get(); // Trim names

      debugPrint(
          '${playersQuery.docs.length} players found to reset team field');

      // Update each player's team to ""
      for (var doc in playersQuery.docs) {
        await doc.reference.update({'team': ""});
      }

      debugPrint('Players team field updated to empty string');
      isLoading = false;
    } catch (e) {
      debugPrint('Error saving match or updating players: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ElevatedButton(
        onPressed: () async {
          setState(() {
            isLoading = true;
          });

          try {
            await saveMatchDetails(MatchDetails(
                teamA: Team(
                    name: widget.teamAName,
                    runs: widget.teamARuns,
                    wickets: widget.teamAWickets,
                    overs: 8,
                    players: teamAPlayers),
                teamB: Team(
                    name: widget.teamBName,
                    runs: widget.teamBRuns,
                    wickets: widget.teamBWickets,
                    overs: 8,
                    players: teamBPlayers),
                venue: 'Ch. Shivaji Ground, Sambhaji Nagar',
                date:
                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                matchSummary: widget.matchResult,
                teamAWon:
                    widget.matchResult.contains('team A won') ? true : false,
                victoryMargin: '${widget.target - widget.teamBRuns}'));

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => StartingScreen()),
                  (Route<dynamic> route) => false);
            }
          } catch (e) {
            debugPrint('Error creating new match: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
              setState(() {
                isLoading = false;
              });
            }
          }
        },
        style: ButtonStyle(
          fixedSize: WidgetStatePropertyAll(Size(100, 80)),
          backgroundColor: WidgetStateProperty.all<Color>(
              Theme.of(context).colorScheme.primary),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : const Text(
                "New Match",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
      ),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMatchDetails, // Proper refresh action
          ),
        ],
        title: const Text('Match Summary',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<MatchDetails>(
        future: _matchDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading match details: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (snapshot.hasData) {
            return _buildBody(context, snapshot.data!);
          } else {
            return const Center(child: Text('No match data available'));
          }
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, MatchDetails match) {
    return SingleChildScrollView(
      child: summary == null
          ? Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _generateSummary,
                      child: const Text("Generate Match Summary"),
                    ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _matchHeader(context, match),
                  const SizedBox(height: 20),
                  _victorySummary(context, match),
                  const SizedBox(height: 20),
                  _matchInfoCard(context, match),
                  const SizedBox(height: 24),
                  _teamSection(context, match.teamA, match.teamAWon),
                  const SizedBox(height: 24),
                  _teamSection(context, match.teamB, !match.teamAWon),
                  const SizedBox(height: 24),
                  _matchSummarySection(context, match),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 5)
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        summary!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _copySummary,
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy Summary"),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _matchHeader(BuildContext context, MatchDetails match) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.teamA.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${match.teamA.runs}/${match.teamA.wickets}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: match.teamAWon
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87,
                        ),
                      ),
                      Text(
                        '(${match.teamA.overs.toStringAsFixed(1)} overs)', // Proper cricket overs format
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.teamB.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${match.teamB.runs}/${match.teamB.wickets}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: !match.teamAWon
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87,
                        ),
                      ),
                      Text(
                        '(${match.teamB.overs.toStringAsFixed(1)} overs)', // Proper cricket overs format
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _victorySummary(BuildContext context, MatchDetails match) {
    final winningTeam = match.teamAWon ? match.teamA.name : match.teamB.name;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$winningTeam won by ${match.victoryMargin}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchInfoCard(BuildContext context, MatchDetails match) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  match.date,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.venue,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamSection(BuildContext context, Team team, bool isWinner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              team.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (isWinner)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Divider(),
        const SizedBox(height: 8),
        team.players.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No player data available'),
                ),
              )
            : _buildPlayersList(context, team.players),
      ],
    );
  }

  Widget _buildPlayersList(BuildContext context, List<PlayerStat> players) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, index) {
        return _playerCard(context, players[index]);
      },
    );
  }

  Widget _playerCard(BuildContext context, PlayerStat player) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (player.isMotm)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'MOTM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (player.runs > 0)
                  _statItem(
                    'Runs',
                    '${player.runs}',
                    player.ballsFaced > 0 ? '(${player.ballsFaced} balls)' : '',
                  ),
                if (player.wickets > 0)
                  _statItem(
                    'Wickets',
                    '${player.wickets}',
                    player.ballsBowled > 0
                        ? '(${player.runsGiven}/${(player.ballsBowled / 6).toStringAsFixed(1)} overs)' // Correct overs format
                        : '',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matchSummarySection(BuildContext context, MatchDetails match) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              match.matchSummary,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
