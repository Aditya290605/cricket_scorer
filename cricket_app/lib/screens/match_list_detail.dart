import 'package:flutter/material.dart';

class MatchListDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> matchData;

  const MatchListDetailsScreen({
    super.key,
    required this.matchData,
  });

  // FIX: Determine winner based on actual runs, not stored flag
  bool _didTeamAWin() {
    final teamA = matchData['teams']?['teamA'];
    final teamB = matchData['teams']?['teamB'];
    
    if (teamA == null || teamB == null) {
      return matchData['teamAWon'] ?? false;
    }
    
    final teamARuns = teamA['runs'] ?? 0;
    final teamBRuns = teamB['runs'] ?? 0;
    
    return teamARuns > teamBRuns;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Match Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match Header Card
            _buildMatchHeaderCard(),
            const SizedBox(height: 16),

            // Match Result Card
            _buildMatchResultCard(),
            const SizedBox(height: 16),

            // Teams Score Card
            _buildTeamsScoreCard(),
            const SizedBox(height: 16),

            // Match Analytics Cards
            _buildMatchAnalyticsCards(),
            const SizedBox(height: 16),

            // Team A Players
            _buildTeamPlayersCard('A'),
            const SizedBox(height: 16),

            // Team B Players
            _buildTeamPlayersCard('B'),
            const SizedBox(height: 16),

            // Match Summary Card
            _buildMatchSummaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue[600], size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    matchData['venue'] ?? 'Unknown Venue',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  matchData['date'] ?? 'Unknown Date',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            if (matchData['target'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Target: ${matchData['target']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMatchResultCard() {
    // FIX: Use correct winner logic
    bool teamAWon = _didTeamAWin();
    String teamAName = matchData['teams']?['teamA']?['name'] ?? 'Team A';
    String teamBName = matchData['teams']?['teamB']?['name'] ?? 'Team B';
    String winnerName = teamAWon ? teamAName : teamBName;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green[400]!, Colors.green[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '$winnerName Won',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (matchData['victoryMargin'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'by ${matchData['victoryMargin']}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsScoreCard() {
    Map<String, dynamic> teamA = matchData['teams']?['teamA'] ?? {};
    Map<String, dynamic> teamB = matchData['teams']?['teamB'] ?? {};

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Match Score',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),

            // FIX: Use correct winner logic
            // Team A Score
            _buildTeamScoreRow(
              teamName: teamA['name'] ?? 'Team A',
              runs: teamA['runs'] ?? 0,
              wickets: teamA['wickets'] ?? 0,
              overs: teamA['overs'] ?? 0.0,
              isWinner: _didTeamAWin(),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),

            // Team B Score
            _buildTeamScoreRow(
              teamName: teamB['name'] ?? 'Team B',
              runs: teamB['runs'] ?? 0,
              wickets: teamB['wickets'] ?? 0,
              overs: teamB['overs'] ?? 0.0,
              isWinner: !_didTeamAWin(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreRow({
    required String teamName,
    required int runs,
    required int wickets,
    required double overs,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinner ? Colors.green[300]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              teamName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isWinner ? Colors.green[800] : Colors.grey[800],
              ),
            ),
          ),
          Text(
            '$runs/$wickets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.green[800] : Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($overs overs)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (isWinner)
            Icon(
              Icons.emoji_events,
              color: Colors.green[600],
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildMatchAnalyticsCards() {
    // Find highest run scorer
    Map<String, dynamic> topScorer = _getTopScorer();
    // Find highest wicket taker
    Map<String, dynamic> topBowler = _getTopBowler();

    return Column(
      children: [
        // Top Performers Header
        Text(
          'Match Highlights',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Highest Run Scorer Card
            Expanded(
              child: _buildPerformanceCard(
                title: 'Top Scorer',
                playerName: topScorer['name'] ?? 'N/A',
                stat: '${topScorer['runs'] ?? 0}',
                subStat: '(${topScorer['ballsFaced'] ?? 0} balls)',
                icon: Icons.sports_cricket,
                gradient: [Colors.orange[400]!, Colors.orange[600]!],
              ),
            ),
            const SizedBox(width: 12),

            // Highest Wicket Taker Card
            Expanded(
              child: _buildPerformanceCard(
                title: 'Top Bowler',
                playerName: topBowler['name'] ?? 'N/A',
                stat: '${topBowler['wickets'] ?? 0}',
                subStat: '(${topBowler['runsGiven'] ?? 0} runs)',
                icon: Icons.sports_baseball,
                gradient: [Colors.purple[400]!, Colors.purple[600]!],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceCard({
    required String title,
    required String playerName,
    required String stat,
    required String subStat,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stat,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subStat,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              playerName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamPlayersCard(String team) {
    String teamKey = 'team$team';
    Map<String, dynamic> teamData = matchData['teams']?[teamKey] ?? {};
    List<dynamic> players = teamData['players'] ?? [];
    String teamName = teamData['name'] ?? 'Team $team';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    teamName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${players.length} Players',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Players list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: players.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                Map<String, dynamic> player = players[index];
                bool isMotm = player['isMotm'] ?? false;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // Player name with MOTM indicator
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            if (isMotm) ...[
                              Icon(
                                Icons.star,
                                color: Colors.amber[600],
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                player['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isMotm
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isMotm
                                      ? Colors.amber[800]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Batting stats
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${player['runs'] ?? 0} runs',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '(${player['ballsFaced'] ?? 0} balls)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bowling stats
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${player['wickets'] ?? 0} wkts',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '(${player['runsGiven'] ?? 0} runs)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSummaryCard() {
    String summary = matchData['matchSummary'] ?? 'No match summary available';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey[700]!,
              Colors.blueGrey[900]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.article,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Match Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        color: Colors.white70,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Match Report',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
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

  Map<String, dynamic> _getTopScorer() {
    Map<String, dynamic> topScorer = {
      'name': 'N/A',
      'runs': 0,
      'ballsFaced': 0
    };
    int maxRuns = -1;

    // Check Team A players
    List<dynamic> teamAPlayers = matchData['teams']?['teamA']?['players'] ?? [];
    for (var player in teamAPlayers) {
      int runs = player['runs'] ?? 0;
      if (runs > maxRuns) {
        maxRuns = runs;
        topScorer = player;
      }
    }

    // Check Team B players
    List<dynamic> teamBPlayers = matchData['teams']?['teamB']?['players'] ?? [];
    for (var player in teamBPlayers) {
      int runs = player['runs'] ?? 0;
      if (runs > maxRuns) {
        maxRuns = runs;
        topScorer = player;
      }
    }

    return topScorer;
  }

  Map<String, dynamic> _getTopBowler() {
    Map<String, dynamic> topBowler = {
      'name': 'N/A',
      'wickets': 0,
      'runsGiven': 0
    };
    int maxWickets = -1;

    // Check Team A players
    List<dynamic> teamAPlayers = matchData['teams']?['teamA']?['players'] ?? [];
    for (var player in teamAPlayers) {
      int wickets = player['wickets'] ?? 0;
      if (wickets > maxWickets) {
        maxWickets = wickets;
        topBowler = player;
      }
    }

    // Check Team B players
    List<dynamic> teamBPlayers = matchData['teams']?['teamB']?['players'] ?? [];
    for (var player in teamBPlayers) {
      int wickets = player['wickets'] ?? 0;
      if (wickets > maxWickets) {
        maxWickets = wickets;
        topBowler = player;
      }
    }

    return topBowler;
  }
}
