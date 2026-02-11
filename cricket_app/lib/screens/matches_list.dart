import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_app/screens/match_list_detail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen>
    with TickerProviderStateMixin {
  List<DocumentSnapshot> allMatches = [];
  List<DocumentSnapshot> filteredMatches = [];

  String searchQuery = '';
  String selectedDate = '';
  bool isLoading = true;
  bool showFilters = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    fetchMatches();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  void fetchMatches() async {
    setState(() => isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('match_summary')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      // No need for client side sorting as we are using server side sorting
      /*
      snapshot.docs.sort((a, b) {
        // Try using timestamp field first (more accurate)
        final aTimestamp = a.data()['timestamp'];
        final bTimestamp = b.data()['timestamp'];
        
        if (aTimestamp != null && bTimestamp != null) {
          // Both have timestamps - compare them (newest first)
          final aDate = (aTimestamp as Timestamp).toDate();
          final bDate = (bTimestamp as Timestamp).toDate();
          return bDate.compareTo(aDate);
        }
        
        // Fall back to parsing date string
        final aDate = parseDate(a['date']);
        final bDate = parseDate(b['date']);
        return bDate.compareTo(aDate);
      });
      */

      setState(() {
        allMatches = snapshot.docs;
        isLoading = false;
        applyFilters();
      });

      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading matches: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  DateTime parseDate(String dateString) {
    try {
      return DateFormat("d/M/yyyy").parse(dateString);
    } catch (_) {
      return DateTime(1900);
    }
  }

  void applyFilters() {
    List<DocumentSnapshot> temp = allMatches;

    if (selectedDate.isNotEmpty) {
      temp = temp.where((doc) => doc['date'] == selectedDate).toList();
    }

    if (searchQuery.isNotEmpty) {
      temp = temp.where((doc) {
        final teamA = doc['teams']['teamA']['name'].toString().toLowerCase();
        final teamB = doc['teams']['teamB']['name'].toString().toLowerCase();
        return teamA.contains(searchQuery.toLowerCase()) ||
            teamB.contains(searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredMatches = temp;
    });
  }

  void _clearAllFilters() {
    _searchController.clear();
    _dateController.clear();
    searchQuery = '';
    selectedDate = '';
    applyFilters();
  }

  // FIX: Determine winner based on actual runs, not stored flag
  bool _didTeamAWin(Map<String, dynamic> data) {
    final teamA = data['teams']?['teamA'];
    final teamB = data['teams']?['teamB'];

    if (teamA == null || teamB == null) {
      return data['teamAWon'] ?? false;
    }

    final teamARuns = teamA['runs'] ?? 0;
    final teamBRuns = teamB['runs'] ?? 0;

    return teamARuns > teamBRuns;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1A237E),
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  showFilters ? Icons.filter_list_off : Icons.filter_list,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => showFilters = !showFilters),
                tooltip: 'Filter',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: fetchMatches,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Match Central',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    '${allMatches.length} matches played',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF3949AB),
                      Color(0xFF5C6BC0),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: 20,
                      child: Icon(
                        Icons.sports_cricket,
                        size: 150,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filter Section (Collapsible)
          if (showFilters)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by team name...',
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF1A237E)),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  searchQuery = '';
                                  applyFilters();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        searchQuery = value;
                        applyFilters();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        hintText: 'Filter by date (e.g., 28/12/2024)',
                        prefixIcon: const Icon(Icons.calendar_today,
                            color: Color(0xFF1A237E)),
                        suffixIcon: selectedDate.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _dateController.clear();
                                  selectedDate = '';
                                  applyFilters();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        selectedDate = value.trim();
                        applyFilters();
                      },
                    ),
                    if (searchQuery.isNotEmpty || selectedDate.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Filters'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Results Count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    filteredMatches.isEmpty
                        ? 'No matches found'
                        : '${filteredMatches.length} Match${filteredMatches.length != 1 ? 'es' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const Spacer(),
                  if (filteredMatches.length != allMatches.length &&
                      filteredMatches.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Filtered',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Match List
          isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A237E)),
                  ),
                )
              : filteredMatches.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sports_cricket_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matches found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Play some matches to see them here!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final match = filteredMatches[index];
                            return _buildMatchCard(match, index);
                          },
                          childCount: filteredMatches.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(DocumentSnapshot match, int index) {
    final data = match.data() as Map<String, dynamic>;
    final teamA = data['teams']['teamA'];
    final teamB = data['teams']['teamB'];
    final date = data['date'] ?? '';

    // FIX: Use correct winner logic based on runs comparison
    final teamAWon = _didTeamAWin(data);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A237E).withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchListDetailsScreen(
                          matchData: data,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // Header - Date & Venue
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E).withOpacity(0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Match #${allMatches.length - allMatches.indexOf(match)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.calendar_today,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score Section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Team A
                            Expanded(
                              child: _buildTeamScore(
                                teamName: teamA['name'] ?? 'Team A',
                                runs: teamA['runs'] ?? 0,
                                wickets: teamA['wickets'] ?? 0,
                                isWinner: teamAWon,
                                alignment: CrossAxisAlignment.start,
                              ),
                            ),

                            // VS Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange.shade400,
                                          Colors.red.shade400,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'VS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Team B
                            Expanded(
                              child: _buildTeamScore(
                                teamName: teamB['name'] ?? 'Team B',
                                runs: teamB['runs'] ?? 0,
                                wickets: teamB['wickets'] ?? 0,
                                isWinner: !teamAWon,
                                alignment: CrossAxisAlignment.end,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Result Footer
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: teamAWon
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 18,
                              color: teamAWon
                                  ? Colors.green.shade700
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${teamAWon ? teamA['name'] : teamB['name']} won',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: teamAWon
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamScore({
    required String teamName,
    required int runs,
    required int wickets,
    required bool isWinner,
    required CrossAxisAlignment alignment,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isWinner && alignment == CrossAxisAlignment.start)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.emoji_events,
                    size: 16, color: Colors.amber[700]),
              ),
            Flexible(
              child: Text(
                teamName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isWinner ? const Color(0xFF1A237E) : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isWinner && alignment == CrossAxisAlignment.end)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.emoji_events,
                    size: 16, color: Colors.amber[700]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$runs/$wickets',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isWinner ? const Color(0xFF1A237E) : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
