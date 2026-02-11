import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  String selectedTab = 'All';
  String selectedCapFilter =
      'All Time'; // Cap filter: 'All Time', 'This Week', 'By Match'
  String? selectedMatchId;
  bool isLoading = true;
  String? errorMessage;

  // Match list for "By Match" filter
  List<Map<String, dynamic>> matches = [];

  // Dynamic data from Firebase
  Map<String, dynamic> orangeCapWinner = {
    'name': 'Loading...',
    'runs': 0,
    'matches': 0,
    'team': '-',
  };

  Map<String, dynamic> purpleCapWinner = {
    'name': 'Loading...',
    'wickets': 0,
    'matches': 0,
    'team': '-',
  };

  List<Map<String, dynamic>> players = [];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fetchMatchList();
    _fetchLeaderboardData();
  }

  Future<void> _fetchMatchList() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('match_summary')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> loadedMatches = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedMatches.add({
          'id': doc.id,
          'date': data['date'] ?? 'Unknown Date',
          'teamA': data['teams']?['teamA']?['name'] ?? 'Team A',
          'teamB': data['teams']?['teamB']?['name'] ?? 'Team B',
          'timestamp': data['timestamp'],
        });
      }

      setState(() {
        matches = loadedMatches;
      });
    } catch (e) {
      debugPrint('Error loading matches: $e');
    }
  }

  Future<void> _fetchLeaderboardData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      if (selectedCapFilter == 'All Time') {
        await _fetchAllTimeStats();
      } else if (selectedCapFilter == 'This Week') {
        await _fetchThisWeekStats();
      } else if (selectedCapFilter == 'By Match' && selectedMatchId != null) {
        await _fetchMatchStats(selectedMatchId!);
      } else {
        await _fetchAllTimeStats(); // Fallback
      }

      _slideController.forward();
      _fadeController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load leaderboard: $e';
      });
      debugPrint('Error fetching leaderboard: $e');
    }
  }

  Future<void> _fetchAllTimeStats() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final friendUserIds = currentUser?.friends ?? [];

    debugPrint('=== LEADERBOARD DEBUG ===');
    debugPrint('Current user: ${currentUser?.name}');
    debugPrint('Friend user IDs count: ${friendUserIds.length}');

    // Fetch player IDs and names for friends
    Set<String> friendPlayerIds = {};
    Set<String> friendNames = {};

    if (friendUserIds.isNotEmpty) {
      // Fetch friend user documents to get their linkedPlayerIds and names
      for (String friendUserId in friendUserIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final linkedPlayerId = userData['linkedPlayerId'] as String?;
            final name = userData['name'] as String?;

            if (linkedPlayerId != null) {
              friendPlayerIds.add(linkedPlayerId);
            }
            if (name != null) {
              friendNames.add(name);
            }
          }
        } catch (e) {
          debugPrint('Error fetching friend user: $e');
        }
      }
    }

    debugPrint('Friend player IDs: $friendPlayerIds');
    debugPrint('Friend names: $friendNames');

    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('players').get();

    List<Map<String, dynamic>> loadedPlayers = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      loadedPlayers.add({
        'id': doc.id,
        'name': data['playerName'] ?? 'Unknown',
        'runs': data['totalRuns'] ?? 0,
        'sr': _calculateStrikeRate(
            data['totalRuns'] ?? 0, data['ballsFaced'] ?? 0),
        'wickets': data['wickets'] ?? 0,
        'balls': data['ballsBowled'] ?? 0,
        'economy': _calculateEconomy(
            data['runsConceded'] ?? 0, data['ballsBowled'] ?? 0),
        'team': data['team'] ?? '-',
        'type': (data['role'] ?? data['playerType'] ?? 'batsman').toLowerCase(),
        'matches': data['matches'] ?? 0,
        'fours': data['fours'] ?? 0,
        'sixes': data['sixes'] ?? 0,
        'ballsFaced': data['ballsFaced'] ?? 0,
      });
    }

    debugPrint('Total players fetched: ${loadedPlayers.length}');

    // Filter to friends only by matching player ID or name
    if (friendPlayerIds.isNotEmpty || friendNames.isNotEmpty) {
      loadedPlayers = loadedPlayers.where((player) {
        final playerId = player['id'] as String?;
        final playerName = player['name'] as String?;

        return (playerId != null && friendPlayerIds.contains(playerId)) ||
            (playerName != null && friendNames.contains(playerName));
      }).toList();
    }

    debugPrint('Players after filtering: ${loadedPlayers.length}');

    _calculateCapWinners(loadedPlayers);

    setState(() {
      players = loadedPlayers;
      isLoading = false;
    });
  }

  Future<void> _fetchThisWeekStats() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final friendUserIds = currentUser?.friends ?? [];

    // Fetch player IDs and names for friends
    Set<String> friendPlayerIds = {};
    Set<String> friendNames = {};

    if (friendUserIds.isNotEmpty) {
      for (String friendUserId in friendUserIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            if (userData['linkedPlayerId'] != null) {
              friendPlayerIds.add(userData['linkedPlayerId']);
            }
            if (userData['name'] != null) {
              friendNames.add(userData['name']);
            }
          }
        } catch (e) {
          debugPrint('Error fetching friend user: $e');
        }
      }
    }

    // Calculate start of current week (Monday)
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    // Fetch matches from this week
    final matchSnapshot = await FirebaseFirestore.instance
        .collection('match_summary')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDate))
        .get();

    // Aggregate player stats from this week's matches
    Map<String, Map<String, dynamic>> playerStats = {};

    for (var doc in matchSnapshot.docs) {
      final data = doc.data();
      final teams = data['teams'] as Map<String, dynamic>?;

      if (teams != null) {
        // Process both teams
        for (var teamKey in ['teamA', 'teamB']) {
          final team = teams[teamKey] as Map<String, dynamic>?;
          final teamName = team?['name'] ?? '';
          final playersList = team?['players'] as List<dynamic>? ?? [];

          for (var player in playersList) {
            final name = player['name'] ?? '';
            if (name.isEmpty) continue;

            if (!playerStats.containsKey(name)) {
              playerStats[name] = {
                'name': name,
                'runs': 0,
                'wickets': 0,
                'ballsFaced': 0,
                'ballsBowled': 0,
                'team': teamName,
                'matches': 0,
              };
            }

            playerStats[name]!['runs'] += (player['runs'] ?? 0) as int;
            playerStats[name]!['wickets'] += (player['wickets'] ?? 0) as int;
            playerStats[name]!['ballsFaced'] +=
                (player['ballsFaced'] ?? 0) as int;
            playerStats[name]!['ballsBowled'] +=
                (player['ballsBowled'] ?? 0) as int;
            playerStats[name]!['matches'] =
                (playerStats[name]!['matches'] ?? 0) + 1;
          }
        }
      }
    }

    List<Map<String, dynamic>> loadedPlayers = playerStats.values
        .map((p) => {
              ...p,
              'sr': _calculateStrikeRate(p['runs'] ?? 0, p['ballsFaced'] ?? 0),
              'economy': _calculateEconomy(0, p['ballsBowled'] ?? 0),
              'type': 'player',
            })
        .toList();

    // Filter to friends only by name
    if (friendNames.isNotEmpty) {
      loadedPlayers = loadedPlayers.where((player) {
        final playerName = player['name'] as String?;
        return playerName != null && friendNames.contains(playerName);
      }).toList();
    }

    _calculateCapWinners(loadedPlayers);

    setState(() {
      players = loadedPlayers;
      isLoading = false;
    });
  }

  Future<void> _fetchMatchStats(String matchId) async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final friendUserIds = currentUser?.friends ?? [];

    // Fetch player IDs and names for friends
    Set<String> friendPlayerIds = {};
    Set<String> friendNames = {};

    if (friendUserIds.isNotEmpty) {
      for (String friendUserId in friendUserIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            if (userData['linkedPlayerId'] != null) {
              friendPlayerIds.add(userData['linkedPlayerId']);
            }
            if (userData['name'] != null) {
              friendNames.add(userData['name']);
            }
          }
        } catch (e) {
          debugPrint('Error fetching friend user: $e');
        }
      }
    }

    final doc = await FirebaseFirestore.instance
        .collection('match_summary')
        .doc(matchId)
        .get();

    if (!doc.exists) {
      setState(() {
        players = [];
        isLoading = false;
      });
      return;
    }

    final data = doc.data()!;
    final teams = data['teams'] as Map<String, dynamic>?;

    List<Map<String, dynamic>> loadedPlayers = [];

    if (teams != null) {
      for (var teamKey in ['teamA', 'teamB']) {
        final team = teams[teamKey] as Map<String, dynamic>?;
        final teamName = team?['name'] ?? '';
        final playersList = team?['players'] as List<dynamic>? ?? [];

        for (var player in playersList) {
          loadedPlayers.add({
            'name': player['name'] ?? 'Unknown',
            'runs': player['runs'] ?? 0,
            'wickets': player['wickets'] ?? 0,
            'ballsFaced': player['ballsFaced'] ?? 0,
            'ballsBowled': player['ballsBowled'] ?? 0,
            'team': teamName,
            'sr': _calculateStrikeRate(
                player['runs'] ?? 0, player['ballsFaced'] ?? 0),
            'economy': _calculateEconomy(
                player['runsGiven'] ?? 0, player['ballsBowled'] ?? 0),
            'type': 'player',
            'matches': 1,
          });
        }
      }
    }

    // Filter to friends only by name
    if (friendNames.isNotEmpty) {
      loadedPlayers = loadedPlayers.where((player) {
        final playerName = player['name'] as String?;
        return playerName != null && friendNames.contains(playerName);
      }).toList();
    }

    _calculateCapWinners(loadedPlayers);

    setState(() {
      players = loadedPlayers;
      isLoading = false;
    });
  }

  void _calculateCapWinners(List<Map<String, dynamic>> playerList) {
    // Sort by runs to find Orange Cap
    List<Map<String, dynamic>> runsSorted = List.from(playerList);
    runsSorted.sort((a, b) => (b['runs'] as int).compareTo(a['runs'] as int));

    if (runsSorted.isNotEmpty && runsSorted[0]['runs'] > 0) {
      orangeCapWinner = {
        'name': runsSorted[0]['name'],
        'runs': runsSorted[0]['runs'],
        'matches': runsSorted[0]['matches'] ?? 0,
        'team': runsSorted[0]['team'],
      };
    } else {
      orangeCapWinner = {
        'name': 'No runs scored yet',
        'runs': 0,
        'matches': 0,
        'team': '-',
      };
    }

    // Find Purple Cap (highest wicket taker)
    List<Map<String, dynamic>> bowlersSorted = List.from(playerList);
    bowlersSorted
        .sort((a, b) => (b['wickets'] as int).compareTo(a['wickets'] as int));

    if (bowlersSorted.isNotEmpty && bowlersSorted[0]['wickets'] > 0) {
      purpleCapWinner = {
        'name': bowlersSorted[0]['name'],
        'wickets': bowlersSorted[0]['wickets'],
        'matches': bowlersSorted[0]['matches'] ?? 0,
        'team': bowlersSorted[0]['team'],
      };
    } else {
      purpleCapWinner = {
        'name': 'No wickets taken yet',
        'wickets': 0,
        'matches': 0,
        'team': '-',
      };
    }
  }

  // Reset all player statistics
  Future<void> _resetAllStats() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Stats?'),
        content: const Text(
          'This will reset ALL player statistics (runs, wickets, etc.) to zero. This action cannot be undone!\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Reset All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot =
          await FirebaseFirestore.instance.collection('players').get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'totalRuns': 0,
          'wickets': 0,
          'ballsFaced': 0,
          'ballsBowled': 0,
          'runsGiven': 0,
          'fours': 0,
          'sixes': 0,
          'matches': 0,
          'team': '',
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All player stats have been reset!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload the data
      await _fetchLeaderboardData();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset stats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateStrikeRate(int runs, int balls) {
    if (balls == 0) return 0.0;
    return (runs / balls) * 100;
  }

  double _calculateEconomy(int runsGiven, int ballsBowled) {
    if (ballsBowled == 0) return 0.0;
    return (runsGiven / ballsBowled) * 6;
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredPlayers {
    if (selectedTab == 'All') return players;
    return players
        .where((player) => player['type'] == selectedTab.toLowerCase())
        .toList();
  }

  void _showMatchPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Match',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No matches found'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final isSelected = selectedMatchId == match['id'];
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue[100]
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sports_cricket,
                              color: isSelected ? Colors.blue : Colors.grey,
                            ),
                          ),
                          title: Text(
                            '${match['teamA']} vs ${match['teamB']}',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(match['date']),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              selectedMatchId = match['id'];
                              selectedCapFilter = 'By Match';
                            });
                            _fetchLeaderboardData();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        appBar: AppBar(
          title: const Text('Friends Leaderboard'),
          backgroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading player stats...'),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        appBar: AppBar(
          title: const Text('Friends Leaderboard'),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchLeaderboardData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: RefreshIndicator(
        onRefresh: _fetchLeaderboardData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black54),
                  onPressed: _fetchLeaderboardData,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt, color: Colors.red),
                  onPressed: _resetAllStats,
                  tooltip: 'Reset All Stats',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'Friends Leaderboard',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2196F3), Colors.white],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            // Cap Filter Chips
                            _buildCapFilterChips(),

                            const SizedBox(height: 20),

                            // Cap Winners with Hero Animation
                            Row(
                              children: [
                                Expanded(
                                  child: Hero(
                                    tag: 'orange-cap',
                                    child: _buildCapCard(
                                      'Orange Cap',
                                      orangeCapWinner['name'],
                                      '${orangeCapWinner['runs']} runs',
                                      orangeCapWinner['team'],
                                      const Color(0xFFFF8C42),
                                      'assets/orange_cap.png',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Hero(
                                    tag: 'purple-cap',
                                    child: _buildCapCard(
                                      'Purple Cap',
                                      purpleCapWinner['name'],
                                      '${purpleCapWinner['wickets']} wickets',
                                      purpleCapWinner['team'],
                                      const Color(0xFF8E44AD),
                                      'assets/purple_cap.png',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Filter Tabs
                            _buildFilterTabs(),

                            const SizedBox(height: 20),

                            // Players Table with Animation
                            _buildAnimatedTable(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCapFilterChip('All Time', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildCapFilterChip('This Week', Icons.date_range),
            const SizedBox(width: 8),
            _buildMatchFilterChip(),
          ],
        ),
      ),
    );
  }

  Widget _buildCapFilterChip(String label, IconData icon) {
    final isSelected = selectedCapFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCapFilter = label;
          selectedMatchId = null;
        });
        _fetchLeaderboardData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchFilterChip() {
    final isSelected = selectedCapFilter == 'By Match';
    final hasMatch = selectedMatchId != null;

    String label = 'By Match';
    if (hasMatch && matches.isNotEmpty) {
      final match = matches.firstWhere(
        (m) => m['id'] == selectedMatchId,
        orElse: () => {'teamA': '', 'teamB': ''},
      );
      if (match['teamA'] != '') {
        label = '${match['teamA']} vs ${match['teamB']}';
      }
    }

    return GestureDetector(
      onTap: _showMatchPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_cricket,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapCard(String capType, String playerName, String stat,
      String team, Color color, String imgAddress) {
    return GestureDetector(
      onTap: () => _showPlayerDetails(playerName, stat, team),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Image.asset(
              imgAddress,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 12),
            Text(
              capType,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              playerName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              team,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                stat,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = ['All', 'Batsman', 'Bowler', 'Allrounder'];

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedTab = tab;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF2196F3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnimatedTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.leaderboard,
                    color: Color(0xFF2196F3), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Player Rankings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredPlayers.length} Players',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildTableHeader(),
          if (filteredPlayers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No player data available',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...filteredPlayers.asMap().entries.map((entry) {
              return _buildAnimatedPlayerRow(
                  entry.value, entry.key + 1, entry.key);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          SizedBox(width: 32),
          Expanded(
            flex: 3,
            child: Text(
              'Player',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Runs',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'SR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Wkts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPlayerRow(
      Map<String, dynamic> player, int position, int index) {
    final isOrangeCap = player['name'] == orangeCapWinner['name'] &&
        player['runs'] == orangeCapWinner['runs'] &&
        player['runs'] > 0;
    final isPurpleCap = player['name'] == purpleCapWinner['name'] &&
        player['wickets'] == purpleCapWinner['wickets'] &&
        player['wickets'] > 0;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              onTap: () => _showPlayerDetails(
                  player['name'], '${player['runs']} runs', player['team']),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isOrangeCap
                      ? const Color(0xFFFF8C42).withOpacity(0.1)
                      : isPurpleCap
                          ? const Color(0xFF8E44AD).withOpacity(0.1)
                          : position <= 3
                              ? const Color(0xFF2196F3).withOpacity(0.05)
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOrangeCap
                        ? const Color(0xFFFF8C42).withOpacity(0.3)
                        : isPurpleCap
                            ? const Color(0xFF8E44AD).withOpacity(0.3)
                            : position <= 3
                                ? const Color(0xFF2196F3).withOpacity(0.2)
                                : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: position <= 3
                            ? const LinearGradient(
                                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                              )
                            : null,
                        color: position > 3 ? Colors.grey.shade200 : null,
                        shape: BoxShape.circle,
                        boxShadow: position <= 3
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF2196F3).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: position <= 3
                            ? Icon(
                                position == 1 ? Icons.emoji_events : Icons.star,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '$position',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  player['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOrangeCap) ...[
                                const SizedBox(width: 4),
                                Image.asset('assets/orange_cap.png',
                                    width: 20, height: 20),
                              ],
                              if (isPurpleCap) ...[
                                const SizedBox(width: 4),
                                Image.asset('assets/purple_cap.png',
                                    width: 20, height: 20),
                              ],
                            ],
                          ),
                          Text(
                            player['team'] ?? '-',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${player['runs']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isOrangeCap
                              ? const Color(0xFFFF8C42)
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        player['sr'] != null
                            ? (player['sr'] as double).toStringAsFixed(1)
                            : '0.0',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${player['wickets']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isPurpleCap
                              ? const Color(0xFF8E44AD)
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlayerDetails(String name, String stat, String team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF2196F3),
              child: Text(
                name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join(''),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              team,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                stat,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
