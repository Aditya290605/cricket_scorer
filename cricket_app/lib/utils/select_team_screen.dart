import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class Player {
  final String id;
  final String name;
  final String role;
  final String photoUrl;
  final String assignedTeam; // Track which team player is assigned to
  final String? userUuid; // Link to user for friend filtering
  bool isSelected;

  Player({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl = '',
    this.assignedTeam = '',
    this.userUuid,
    this.isSelected = false,
  });

  // Check if player is available (not assigned to any team)
  bool get isAvailable => assignedTeam.isEmpty;

  // Check if player is on a different team
  bool isOnOtherTeam(String currentTeam) =>
      assignedTeam.isNotEmpty && assignedTeam != currentTeam;

  // Check if player is on the current team
  bool isOnCurrentTeam(String currentTeam) =>
      assignedTeam.isNotEmpty && assignedTeam == currentTeam;
}

class SelectPlayersScreen extends StatefulWidget {
  final String teamName;
  const SelectPlayersScreen({super.key, required this.teamName});

  @override
  _SelectPlayersScreenState createState() => _SelectPlayersScreenState();
}

class _SelectPlayersScreenState extends State<SelectPlayersScreen> {
  bool _isLoading = false;
  List<Player> _allPlayers = []; // All players from Firebase
  List<Player> _filteredPlayers = [];
  List<Player> _selectedPlayers = [];
  TextEditingController nameController = TextEditingController();
  TextEditingController roleController = TextEditingController();
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
    searchController.addListener(_filterPlayers);
    debugPrint('Team Name: ${widget.teamName}');
  }

  @override
  void dispose() {
    nameController.dispose();
    roleController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _filterPlayers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPlayers = List.from(_allPlayers);
      } else {
        _filteredPlayers = _allPlayers
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.role.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _togglePlayerSelection(Player player) {
    // Don't allow selection of players on other teams
    if (player.isOnOtherTeam(widget.teamName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${player.name} is already on ${player.assignedTeam}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      player.isSelected = !player.isSelected;

      if (player.isSelected) {
        _selectedPlayers.add(player);
      } else {
        _selectedPlayers.removeWhere((p) => p.id == player.id);
      }
    });
  }

  void _deselectAllPlayers() {
    HapticFeedback.mediumImpact();
    setState(() {
      // Deselect all players that are selectable (not on other teams)
      for (var player in _allPlayers) {
        if (!player.isOnOtherTeam(widget.teamName)) {
          player.isSelected = false;
        }
      }
      _selectedPlayers.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All selections cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _fetchPlayers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user's friends list
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      final friendUuids = currentUser?.friends ?? [];
      final currentUserUuid = currentUser?.uuid;

      final querySnapshot =
          await FirebaseFirestore.instance.collection('players').get();

      final List<Player> loadedPlayers = [];
      final List<Player> preSelectedPlayers = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String playerTeam = data['team'] ?? '';
        final String? playerUserUuid = data['userUuid'];

        // Include players who are friends OR the current user
        final isFriend =
            playerUserUuid != null && friendUuids.contains(playerUserUuid);
        final isCurrentUser =
            playerUserUuid != null && playerUserUuid == currentUserUuid;

        if (!isFriend && !isCurrentUser) {
          continue; // Skip non-friends and non-current-user
        }

        final player = Player(
          id: doc.id,
          name: data['name'] ?? data['playerName'] ?? 'Unknown',
          role: data['role'] ?? 'Player',
          assignedTeam: playerTeam,
          userUuid: playerUserUuid,
          // Pre-select players that are already on this team
          isSelected: playerTeam == widget.teamName,
        );

        loadedPlayers.add(player);

        // Track pre-selected players
        if (player.isSelected) {
          preSelectedPlayers.add(player);
        }
      }

      // Sort players: current team first, then available, then other teams
      loadedPlayers.sort((a, b) {
        // Current team players first
        if (a.isOnCurrentTeam(widget.teamName) &&
            !b.isOnCurrentTeam(widget.teamName)) return -1;
        if (!a.isOnCurrentTeam(widget.teamName) &&
            b.isOnCurrentTeam(widget.teamName)) return 1;

        // Then available players
        if (a.isAvailable && !b.isAvailable) return -1;
        if (!a.isAvailable && b.isAvailable) return 1;

        // Finally sort by name
        return a.name.compareTo(b.name);
      });

      setState(() {
        _allPlayers = loadedPlayers;
        _filteredPlayers = List.from(loadedPlayers);
        _selectedPlayers = preSelectedPlayers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading players: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmSelection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final selectedIds = _selectedPlayers.map((p) => p.id).toSet();

      for (var player in _allPlayers) {
        final docRef =
            FirebaseFirestore.instance.collection('players').doc(player.id);

        if (selectedIds.contains(player.id)) {
          // Assign selected players to current team
          batch.update(docRef, {'team': widget.teamName});
        } else if (player.assignedTeam == widget.teamName) {
          // Unassign players that were on this team but are now deselected
          batch.update(docRef, {'team': ''});
        }
        // Players on other teams are not modified
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_selectedPlayers.length} players assigned to ${widget.teamName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating players: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Count players by status
    final currentTeamCount =
        _allPlayers.where((p) => p.isOnCurrentTeam(widget.teamName)).length;
    final availableCount = _allPlayers.where((p) => p.isAvailable).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Select for ${widget.teamName}'),
        centerTitle: true,
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          // Deselect All button
          if (_selectedPlayers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: 'Deselect All',
              onPressed: _deselectAllPlayers,
            ),
          if (_selectedPlayers.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedPlayers.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                    'On ${widget.teamName}', currentTeamCount, Colors.green),
                _buildStatChip('Available', availableCount, Colors.blue),
                _buildStatChip(
                    'Selected', _selectedPlayers.length, Colors.orange),
              ],
            ),
          ),
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search players by name or role...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          // Players List
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Confirm Selection Button
          FloatingActionButton.extended(
            heroTag: 'confirm',
            onPressed: _confirmSelection,
            backgroundColor:
                _selectedPlayers.isNotEmpty ? Colors.green : Colors.grey,
            icon: const Icon(Icons.check),
            label: Text(_selectedPlayers.isNotEmpty
                ? 'Confirm (${_selectedPlayers.length})'
                : 'Confirm Selection'),
          ),
          const SizedBox(height: 12),
          // Add Player Button
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showAddPlayerDialog,
            backgroundColor: Colors.blue[900],
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog() {
    nameController.clear();
    roleController.clear();
    showAdaptiveDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Add New Player'),
          contentPadding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Player Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(
                labelText: 'Player Role (Batsman/Bowler/All-rounder)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sports_cricket),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (nameController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter player name')),
                      );
                      return;
                    }
                    await FirebaseFirestore.instance.collection('players').add({
                      'name': nameController.text.trim(),
                      'role': roleController.text.trim().isEmpty
                          ? 'Player'
                          : roleController.text.trim(),
                      'team': '',
                      'totalRuns': 0,
                      'wickets': 0,
                      'ballsFaced': 0,
                      'ballsBowled': 0,
                      'fours': 0,
                      'sixes': 0,
                      'matches': 0,
                    });
                    nameController.clear();
                    roleController.clear();
                    Navigator.pop(context);
                    _fetchPlayers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Player added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Player'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No players available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add players using the + button below',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_filteredPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No players found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _filteredPlayers.length,
      itemBuilder: (context, index) {
        final player = _filteredPlayers[index];
        return _buildPlayerCard(player);
      },
    );
  }

  Widget _buildPlayerCard(Player player) {
    final bool isOnOtherTeam = player.isOnOtherTeam(widget.teamName);
    final bool isOnCurrentTeam = player.isOnCurrentTeam(widget.teamName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: player.isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: player.isSelected
            ? const BorderSide(color: Colors.green, width: 2)
            : isOnOtherTeam
                ? BorderSide(color: Colors.grey[400]!, width: 1)
                : BorderSide.none,
      ),
      color: player.isSelected
          ? Colors.green[50]
          : isOnOtherTeam
              ? Colors.grey[200]
              : null,
      child: InkWell(
        onTap: () => _togglePlayerSelection(player),
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isOnOtherTeam ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      isOnOtherTeam ? Colors.grey : _getRoleColor(player.role),
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isOnOtherTeam ? Colors.grey[600] : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOnOtherTeam
                                  ? Colors.grey.withOpacity(0.2)
                                  : _getRoleColor(player.role).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              player.role,
                              style: TextStyle(
                                color: isOnOtherTeam
                                    ? Colors.grey
                                    : _getRoleColor(player.role),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isOnOtherTeam) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                player.assignedTeam,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (isOnCurrentTeam && !isOnOtherTeam) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Current Team',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: isOnOtherTeam
                      ? Icon(Icons.block, color: Colors.grey[400], size: 28)
                      : player.isSelected
                          ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 28)
                          : Icon(Icons.circle_outlined,
                              color: Colors.grey[400], size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    final lowerRole = role.toLowerCase();
    if (lowerRole.contains('bat')) {
      return Colors.orange;
    } else if (lowerRole.contains('bowl')) {
      return Colors.purple;
    } else if (lowerRole.contains('all')) {
      return Colors.green;
    } else if (lowerRole.contains('keeper') || lowerRole.contains('wicket')) {
      return Colors.blue;
    }
    return Colors.grey;
  }
}
