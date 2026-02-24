import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'feedback_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<AppUser> _searchResults = [];
  List<AppUser> _friendRequests = [];
  List<AppUser> _friends = [];
  Map<String, dynamic>? _playerStats;

  bool _isSearching = false;
  bool _isLoadingStats = true;
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlayerStats();
    _loadFriendsAndRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerStats() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) return;

    try {
      // First try to find by linked player ID
      DocumentSnapshot? playerDoc;

      if (user.linkedPlayerId != null) {
        playerDoc = await FirebaseFirestore.instance
            .collection('players')
            .doc(user.linkedPlayerId)
            .get();
      }

      // If not found, try by name match
      if (playerDoc == null || !playerDoc.exists) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('players')
            .where('playerName', isEqualTo: user.name)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          playerDoc = querySnapshot.docs.first;
        }
      }

      if (playerDoc != null && playerDoc.exists) {
        setState(() {
          _playerStats = playerDoc!.data() as Map<String, dynamic>;
          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _playerStats = {};
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading player stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadFriendsAndRequests() async {
    final authProvider = context.read<AuthProvider>();

    try {
      // Refresh data first to ensure we have latest requests
      await authProvider.refreshUserData();

      final requests = await authProvider.getFriendRequests();

      final friends = await authProvider.getFriends();

      setState(() {
        _friendRequests = requests;
        _friends = friends;
        _isLoadingFriends = false;
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
      setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _refreshFriendsData() async {
    setState(() => _isLoadingFriends = true);

    final authProvider = context.read<AuthProvider>();

    // Refresh user data from Firestore first
    await authProvider.refreshUserData();

    // Then reload friends and requests
    await _loadFriendsAndRequests();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friends list refreshed!'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    final authProvider = context.read<AuthProvider>();
    final results = await authProvider.searchUsersByName(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(String toUuid) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendFriendRequest(toUuid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Friend request sent!' : 'Failed to send request'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        setState(() {
          _searchResults =
              _searchResults.where((u) => u.uuid != toUuid).toList();
        });
      }
    }
  }

  Future<void> _acceptFriendRequest(String fromUuid) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.acceptFriendRequest(fromUuid);

    if (mounted && success) {
      await _loadFriendsAndRequests();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _rejectFriendRequest(String fromUuid) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.rejectFriendRequest(fromUuid);

    if (mounted && success) {
      await _loadFriendsAndRequests();
    }
  }

  Future<void> _deleteFriend(AppUser friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
            'Are you sure you want to remove ${friend.name} from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.deleteFriend(friend.uuid);

      if (mounted) {
        if (success) {
          await _loadFriendsAndRequests();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend removed'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to remove friend'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: const Color(0xFF1E3A5F),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E3A5F),
                      Color(0xFF0D1B2A),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.greenAccent, width: 3),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: user.photoUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  user.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.white70, size: 20),
                        onPressed: () => _showEditProfileDialog(user),
                        tooltip: 'Edit Profile',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getPlayerTypeColor(user.playerType),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.playerType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.feedback_outlined, color: Colors.white),
                onPressed: () => _showFeedbackDialog(user),
                tooltip: 'Send Feedback',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => _showLogoutDialog(context, authProvider),
                tooltip: 'Logout',
              ),
            ],
          ),

          // Stats Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Stats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                ],
              ),
            ),
          ),

          // Friends Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Friends',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // Refresh button
                          IconButton(
                            icon: _isLoadingFriends
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, color: Colors.blue),
                            onPressed:
                                _isLoadingFriends ? null : _refreshFriendsData,
                            tooltip: 'Refresh',
                          ),
                          if (_friendRequests.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_friendRequests.length} requests',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchUsers,
                      decoration: InputDecoration(
                        hintText: 'Search players by name...',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people, size: 18),
                              const SizedBox(width: 8),
                              Text('Friends (${_friends.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add, size: 18),
                              const SizedBox(width: 8),
                              Text('Requests (${_friendRequests.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Results or Friends/Requests
          SliverToBoxAdapter(
            child: SizedBox(
              height: 400,
              child: _searchResults.isNotEmpty || _isSearching
                  ? _buildSearchResults()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFriendsList(),
                        _buildFriendRequestsList(),
                      ],
                    ),
            ),
          ),

          // Send Feedback Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: InkWell(
                onTap: () => _showFeedbackDialog(user),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E3A5F),
                        Color(0xFF0D1B2A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A5F).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.feedback_outlined,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Feedback',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Help us improve the app with your suggestions',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _playerStats ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          'Matches',
          '${stats['matches'] ?? 0}',
          Icons.sports_cricket,
          Colors.blue,
        ),
        _buildStatCard(
          'Runs',
          '${stats['totalRuns'] ?? 0}',
          Icons.trending_up,
          Colors.orange,
        ),
        _buildStatCard(
          'Wickets',
          '${stats['wickets'] ?? stats['totalWickets'] ?? 0}',
          Icons.sports_baseball,
          Colors.purple,
        ),
        _buildStatCard(
          'Strike Rate',
          _calculateStrikeRate(stats),
          Icons.speed,
          Colors.green,
        ),
        _buildStatCard(
          'Fours',
          '${stats['fours'] ?? 0}',
          Icons.looks_4,
          Colors.teal,
        ),
        _buildStatCard(
          'Sixes',
          '${stats['sixes'] ?? 0}',
          Icons.looks_6,
          Colors.red,
        ),
      ],
    );
  }

  String _calculateStrikeRate(Map<String, dynamic> stats) {
    final runs = stats['totalRuns'] ?? 0;
    final balls = stats['ballsFaced'] ?? 0;
    if (balls == 0) return '0.0';
    return ((runs / balls) * 100).toStringAsFixed(1);
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No players found'),
      );
    }

    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isAlreadyFriend =
            currentUser?.friends.contains(user.uuid) ?? false;
        final requestSent =
            currentUser?.friendRequestsSent.contains(user.uuid) ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPlayerTypeColor(user.playerType),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(user.name),
            subtitle: Text(user.playerType),
            trailing: isAlreadyFriend
                ? const Chip(
                    label: Text('Friend', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  )
                : requestSent
                    ? const Chip(
                        label: Text('Pending', style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.orange,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    : IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.blue),
                        onPressed: () => _sendFriendRequest(user.uuid),
                      ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No friends yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for players to add them as friends',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPlayerTypeColor(friend.playerType),
              child: Text(
                friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(friend.name),
            subtitle: Text(friend.playerType),
            trailing: IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.red),
              onPressed: () => _deleteFriend(friend),
              tooltip: 'Remove Friend',
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendRequestsList() {
    if (_isLoadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _friendRequests.length,
      itemBuilder: (context, index) {
        final request = _friendRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPlayerTypeColor(request.playerType),
              child: Text(
                request.name.isNotEmpty ? request.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(request.name),
            subtitle: Text(request.playerType),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _acceptFriendRequest(request.uuid),
                  tooltip: 'Accept',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejectFriendRequest(request.uuid),
                  tooltip: 'Reject',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getPlayerTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'batter':
        return Colors.orange;
      case 'bowler':
        return Colors.purple;
      case 'allrounder':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(AppUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedbackDialog(userName: user.name),
    );
  }

  void _showEditProfileDialog(AppUser user) {
    final nameController = TextEditingController(text: user.name);
    String selectedRole = user.playerType; // 'batter', 'bowler', 'allrounder'
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value:
                      ['batter', 'bowler', 'allrounder'].contains(selectedRole)
                          ? selectedRole
                          : 'allrounder',
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'batter', child: Text('Batter')),
                    DropdownMenuItem(value: 'bowler', child: Text('Bowler')),
                    DropdownMenuItem(
                        value: 'allrounder', child: Text('All Rounder')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRole = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final authProvider = context.read<AuthProvider>();
                  final success = await authProvider.updateProfile(
                    name: nameController.text.trim(),
                    playerType: selectedRole,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update profile'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
