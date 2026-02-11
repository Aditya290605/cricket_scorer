import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_app/screens/toss_screen.dart';
import 'package:flutter/material.dart';
import 'package:cricket_app/utils/select_team_screen.dart'
    show SelectPlayersScreen;

class SelectTeamsScreen extends StatefulWidget {
  const SelectTeamsScreen({super.key});

  @override
  State<SelectTeamsScreen> createState() => _SelectTeamsScreenState();
}

class _SelectTeamsScreenState extends State<SelectTeamsScreen> {
  final TextEditingController _teamAController =
      TextEditingController(text: 'Team A');
  final TextEditingController _teamBController =
      TextEditingController(text: 'Team B');
  bool _isEditingTeamA = false;
  bool _isEditingTeamB = false;

  // Player counts for each team
  int _teamAPlayerCount = 0;
  int _teamBPlayerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPlayerCounts();
  }

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerCounts() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('players').get();

      int teamACount = 0;
      int teamBCount = 0;

      for (var doc in snapshot.docs) {
        final team = doc.data()['team'] ?? '';
        if (team == _teamAController.text) {
          teamACount++;
        } else if (team == _teamBController.text) {
          teamBCount++;
        }
      }

      if (mounted) {
        setState(() {
          _teamAPlayerCount = teamACount;
          _teamBPlayerCount = teamBCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading player counts: $e');
    }
  }

  Future<void> _selectTeam(BuildContext context, String teamName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectPlayersScreen(teamName: teamName),
      ),
    );
    // Reload player counts when returning from player selection
    _loadPlayerCounts();
  }

  Future<void> _resetAllTeamSelections() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Team Selections?'),
        content: const Text(
          'This will remove all players from both teams. You can then select new players for each team.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Clear team field for all players
      final batch = FirebaseFirestore.instance.batch();
      final snapshot =
          await FirebaseFirestore.instance.collection('players').get();

      for (var doc in snapshot.docs) {
        final currentTeam = doc.data()['team'] ?? '';
        if (currentTeam.isNotEmpty) {
          batch.update(doc.reference, {'team': ''});
        }
      }

      await batch.commit();

      // Reset local counts
      setState(() {
        _teamAPlayerCount = 0;
        _teamBPlayerCount = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All team selections have been reset!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting teams: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[900]!, Colors.blue[800]!, Colors.blue[600]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose Your Team',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select or customize your team names below',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: ListView(
                  children: [
                    _buildTeamCard(
                      context,
                      _teamAController.text,
                      Icons.sports_cricket,
                      const Color(0xFF1E88E5),
                      isEditing: _isEditingTeamA,
                      controller: _teamAController,
                      playerCount: _teamAPlayerCount,
                      onEditToggle: () {
                        setState(() {
                          _isEditingTeamA = !_isEditingTeamA;
                          if (!_isEditingTeamA &&
                              _teamAController.text.isEmpty) {
                            _teamAController.text = 'Team A';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTeamCard(
                      context,
                      _teamBController.text,
                      Icons.sports_baseball,
                      const Color(0xFFE53935),
                      isEditing: _isEditingTeamB,
                      controller: _teamBController,
                      playerCount: _teamBPlayerCount,
                      onEditToggle: () {
                        setState(() {
                          _isEditingTeamB = !_isEditingTeamB;
                          if (!_isEditingTeamB &&
                              _teamBController.text.isEmpty) {
                            _teamBController.text = 'Team B';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Reset Teams Button
              if (_teamAPlayerCount > 0 || _teamBPlayerCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _resetAllTeamSelections,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      'Reset Team Selections',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (_teamAPlayerCount < 2 || _teamBPlayerCount < 2)
                          ? Colors.grey
                          : Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  // Validate team names
                  if (_teamAController.text.trim().isEmpty ||
                      _teamBController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter names for both teams'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (_teamAController.text.trim() ==
                      _teamBController.text.trim()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Team names must be different'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Validate player counts (At least 2 players required)
                  if (_teamAPlayerCount < 2 || _teamBPlayerCount < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _teamAPlayerCount < 2 && _teamBPlayerCount < 2
                              ? 'Both teams need at least 2 players'
                              : _teamAPlayerCount < 2
                                  ? '${_teamAController.text} needs at least 2 players'
                                  : '${_teamBController.text} needs at least 2 players',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TossScreen(
                        teamA: _teamAController.text.trim(),
                        teamB: _teamBController.text.trim(),
                        players: const [],
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Start Match',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    String teamName,
    IconData icon,
    Color teamColor, {
    required bool isEditing,
    required TextEditingController controller,
    required int playerCount,
    required VoidCallback onEditToggle,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey[100]!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: teamColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 60,
                      color: teamColor,
                    ),
                  ),
                  // Player count badge
                  if (playerCount > 0)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$playerCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              isEditing
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: 'Enter team name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: teamColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: teamColor, width: 2),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            autofocus: true,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.check, color: teamColor),
                          onPressed: onEditToggle,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          teamName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: teamColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit, size: 20, color: Colors.grey),
                          onPressed: onEditToggle,
                        ),
                      ],
                    ),
              // Player count text
              if (playerCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$playerCount player${playerCount != 1 ? 's' : ''} selected',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _selectTeam(context, controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teamColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  playerCount > 0 ? 'Edit Players' : 'Select Players',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
