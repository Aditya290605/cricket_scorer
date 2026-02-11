import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_app/screens/match_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

class SimpleCricketScorer extends StatefulWidget {
  final String battingTeam;
  final String bowlingTeam;
  final List players1;

  const SimpleCricketScorer({
    super.key,
    required this.battingTeam,
    required this.bowlingTeam,
    required this.players1,
  });

  @override
  State<SimpleCricketScorer> createState() => _SimpleCricketScorerState();
}

// Class to store complete match state for undo functionality
class BallHistoryEntry {
  final int runs;
  final int wickets;
  final int completedOvers;
  final int ballsInCurrentOver;
  final int innings;
  final int targetRuns;
  final int requiredRuns;
  final int remainingBalls;
  final String striker;
  final String nonStriker;
  final String currentBowler;
  final Map<String, BatsmanStats> batsmenStatsSnapshot;
  final Map<String, BowlerStats> bowlerStatsSnapshot;
  final List<BallOutcome> currentOverOutcomesSnapshot;
  final BallOutcome outcome;
  final String description;

  BallHistoryEntry({
    required this.runs,
    required this.wickets,
    required this.completedOvers,
    required this.ballsInCurrentOver,
    required this.innings,
    required this.targetRuns,
    required this.requiredRuns,
    required this.remainingBalls,
    required this.striker,
    required this.nonStriker,
    required this.currentBowler,
    required this.batsmenStatsSnapshot,
    required this.bowlerStatsSnapshot,
    required this.currentOverOutcomesSnapshot,
    required this.outcome,
    required this.description,
  });
}

class _SimpleCricketScorerState extends State<SimpleCricketScorer> {
  // Game state
  int runs = 0;
  int wickets = 0;
  int completedOvers = 0;
  int ballsInCurrentOver = 0;
  int innings = 0;
  int targetRuns = 0;
  int requiredRuns = 0;
  int remainingBalls = 0;
  bool isLoading = false;
  int firstInningRuns = 0;
  int firstInningBallRemaining = 0;
  int firstInningWickets = 0;
  String teamA = '';
  String teamB = '';

  List teamAPlayers = [];
  List teamBPlayers = [];

  String striker = '';
  String nonStriker = '';
  Map<String, BatsmanStats> batsmenStats = {};

  late String currentBowler;
  Map<String, BowlerStats> bowlerStats = {};

  List<BallOutcome> currentOverOutcomes = [];

  // Undo functionality - Ball history stack
  List<BallHistoryEntry> ballHistory = [];
  static const int maxHistorySize = 30; // Keep last 30 balls for undo

  // Partnership tracking
  int partnershipRuns = 0;
  int partnershipBalls = 0;

  // Audio player for horn sound
  final AudioPlayer _hornPlayer = AudioPlayer();

  final List<String> audio4s = [
    'audios/4s/1.mp3',
    'audios/4s/2.mp3',
  ];

  final List<String> audio6s = [
    'audios/6s/1.mp3',
    'audios/6s/2.mp3',
    'audios/6s/3.mp3',
    'audios/6s/4.mp3',
    'audios/6s/5.mp3',
    'audios/6s/6.mp3',
  ];

  final List<String> audioWickets = [
    'audios/wicket/1.mp3',
    'audios/wicket/2.mp3',
    'audios/wicket/3.mp3',
  ];

  Map<String, String> _playerIds = {}; // Map to store playerName -> docId

  @override
  void initState() {
    super.initState();
    fetchAndInitializeTeams();
    if (kDebugMode) {
      debugPrint('${widget.battingTeam} vs ${widget.bowlingTeam}');
    }
  }

  @override
  void dispose() {
    _hornPlayer.dispose();
    super.dispose();
  }

  // Play horn sound
  void _playHornSound() async {
    try {
      await _hornPlayer.stop(); // Stop if already playing
      await _hornPlayer.play(
          AssetSource('IPL Air Horn(Trumpet) - Sound Effect - Download!.mp3'));
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error playing horn: $e');
      }
    }
  }

  // Play random audio from list
  void _playRandomAudio(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _hornPlayer.stop(); // Stop if already playing
      final randomPath = paths[Random().nextInt(paths.length)];
      await _hornPlayer.play(AssetSource(randomPath));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error playing audio: $e');
      }
    }
  }

  void fetchAndInitializeTeams() async {
    try {
      setState(() {
        isLoading = true;
      });

      if (kDebugMode) {
        print(
            '🏏 Fetching players for teams: ${widget.battingTeam} vs ${widget.bowlingTeam}');
      }

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('players')
          .where('team',
              whereIn: [widget.battingTeam, widget.bowlingTeam]).get();

      if (kDebugMode) {
        print('📊 Found ${snapshot.docs.length} total documents');
      }

      List<String> teamA = [];
      List<String> teamB = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) {
          if (kDebugMode) {
            print('⚠️ Document ${doc.id} has null data');
          }
          continue;
        }

        if (kDebugMode) {
          print('📄 Doc ${doc.id}: $data');
        }

        if (!data.containsKey('playerName') || !data.containsKey('team')) {
          if (kDebugMode) {
            print('⚠️ Document ${doc.id} missing required fields');
          }
          continue;
        }

        String name = data['playerName'];
        String team = data['team'];

        _playerIds[name] = doc.id;

        if (kDebugMode) {
          print('👤 Player: $name, Team: $team');
        }

        if (team.trim() == widget.battingTeam.trim()) {
          teamA.add(name);
          if (kDebugMode) {
            print('✅ Added to Team A');
          }
        } else if (team.trim() == widget.bowlingTeam.trim()) {
          teamB.add(name);
          if (kDebugMode) {
            print('✅ Added to Team B');
          }
        } else {
          if (kDebugMode) {
            print(
                '❌ Team "$team" does not match "${widget.battingTeam}" or "${widget.bowlingTeam}"');
          }
        }
      }

      if (kDebugMode) {
        print(
            '📋 Final counts - Team A: ${teamA.length}, Team B: ${teamB.length}');
      }

      // Handle 1v1 case by adding a dummy player
      if (teamA.length == 1) teamA.add("Ghost Player A");
      if (teamB.length == 1) teamB.add("Ghost Player B");

      if (teamA.length < 2 || teamB.isEmpty) {
        if (kDebugMode) {
          print("Not enough players in one of the teams.");
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      setState(() {
        teamAPlayers = List<String>.from(teamA);
        teamBPlayers = List<String>.from(teamB);

        striker = teamAPlayers[0];
        nonStriker = teamAPlayers[1];
        currentBowler = teamBPlayers[0];

        batsmenStats[striker] = BatsmanStats(name: striker, isOnStrike: true);
        batsmenStats[nonStriker] =
            BatsmanStats(name: nonStriker, isOnStrike: false);
        bowlerStats[currentBowler] = BowlerStats(name: currentBowler);
        isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing teams: $e');
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  void _checkBattingTeamWin() {
    if (innings != 1) return;
    // Batting team wins when they EXCEED the target, not just equal it
    if (runs > targetRuns) {
      _endMatch();
    }
  }

  // Helper method to create deep copy of batsmen stats for undo
  Map<String, BatsmanStats> _copyBatsmenStats() {
    Map<String, BatsmanStats> copy = {};
    batsmenStats.forEach((key, value) {
      copy[key] = BatsmanStats(name: value.name, isOnStrike: value.isOnStrike)
        ..runs = value.runs
        ..ballsFaced = value.ballsFaced
        ..fours = value.fours
        ..sixes = value.sixes
        ..isOut = value.isOut;
    });
    return copy;
  }

  // Helper method to create deep copy of bowler stats for undo
  Map<String, BowlerStats> _copyBowlerStats() {
    Map<String, BowlerStats> copy = {};
    bowlerStats.forEach((key, value) {
      copy[key] = BowlerStats(name: value.name)
        ..runs = value.runs
        ..wickets = value.wickets
        ..ballsBowled = value.ballsBowled
        ..extras = value.extras;
    });
    return copy;
  }

  // Save current state before processing ball
  void _saveStateForUndo(BallOutcome outcome, String description) {
    BallHistoryEntry entry = BallHistoryEntry(
      runs: runs,
      wickets: wickets,
      completedOvers: completedOvers,
      ballsInCurrentOver: ballsInCurrentOver,
      innings: innings,
      targetRuns: targetRuns,
      requiredRuns: requiredRuns,
      remainingBalls: remainingBalls,
      striker: striker,
      nonStriker: nonStriker,
      currentBowler: currentBowler,
      batsmenStatsSnapshot: _copyBatsmenStats(),
      bowlerStatsSnapshot: _copyBowlerStats(),
      currentOverOutcomesSnapshot: List<BallOutcome>.from(currentOverOutcomes),
      outcome: outcome,
      description: description,
    );

    ballHistory.add(entry);

    // Keep only last N entries to prevent memory issues
    if (ballHistory.length > maxHistorySize) {
      ballHistory.removeAt(0);
    }
  }

  // Undo last ball
  void _undoLastBall() {
    if (ballHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to undo'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo Last Ball?'),
        content: Text(
          'Undo: ${ballHistory.last.description}\nThis will restore the previous state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performUndo();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Undo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _performUndo() {
    BallHistoryEntry lastState = ballHistory.removeLast();

    setState(() {
      runs = lastState.runs;
      wickets = lastState.wickets;
      completedOvers = lastState.completedOvers;
      ballsInCurrentOver = lastState.ballsInCurrentOver;
      innings = lastState.innings;
      targetRuns = lastState.targetRuns;
      requiredRuns = lastState.requiredRuns;
      remainingBalls = lastState.remainingBalls;
      striker = lastState.striker;
      nonStriker = lastState.nonStriker;
      currentBowler = lastState.currentBowler;

      // Restore batsmen stats
      batsmenStats.clear();
      lastState.batsmenStatsSnapshot.forEach((key, value) {
        batsmenStats[key] =
            BatsmanStats(name: value.name, isOnStrike: value.isOnStrike)
              ..runs = value.runs
              ..ballsFaced = value.ballsFaced
              ..fours = value.fours
              ..sixes = value.sixes
              ..isOut = value.isOut;
      });

      // Restore bowler stats
      bowlerStats.clear();
      lastState.bowlerStatsSnapshot.forEach((key, value) {
        bowlerStats[key] = BowlerStats(name: value.name)
          ..runs = value.runs
          ..wickets = value.wickets
          ..ballsBowled = value.ballsBowled
          ..extras = value.extras;
      });

      // Restore current over outcomes
      currentOverOutcomes =
          List<BallOutcome>.from(lastState.currentOverOutcomesSnapshot);
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Undone: ${lastState.description}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Get outcome description for history
  String _getOutcomeDescription(BallOutcome outcome, int runsOnBall) {
    switch (outcome) {
      case BallOutcome.dot:
        return 'Dot ball';
      case BallOutcome.one:
        return '1 run';
      case BallOutcome.two:
        return '2 runs';
      case BallOutcome.three:
        return '3 runs';
      case BallOutcome.four:
        return 'FOUR!';
      case BallOutcome.six:
        return 'SIX!';
      case BallOutcome.wide:
        return 'Wide ball (+1)';
      case BallOutcome.noBall:
        return 'No ball (+1)';
      case BallOutcome.bye:
        return 'Bye (1 run)';
      case BallOutcome.legBye:
        return 'Leg bye (1 run)';
      case BallOutcome.wicket:
        return 'WICKET!';
      case BallOutcome.runOut:
        return 'RUN OUT!';
    }
  }

  // Calculate Current Run Rate
  double get currentRunRate {
    double totalOvers = completedOvers + (ballsInCurrentOver / 6.0);
    if (totalOvers == 0) return 0.0;
    return runs / totalOvers;
  }

  // Calculate Required Run Rate (for 2nd innings)
  double get requiredRunRate {
    if (innings != 1 || requiredRuns <= 0) return 0.0;
    double remainingOvers = remainingBalls / 6.0;
    if (remainingOvers <= 0) return 0.0;
    return requiredRuns / remainingOvers;
  }

  // Calculate Win Probability for batting team (chasing)
  // Returns value between 0.0 and 1.0 (0% to 100%)
  double get battingTeamWinProbability {
    // Only calculate in 2nd innings
    if (innings != 1) return 0.5;

    // If target already achieved
    if (requiredRuns <= 0) return 1.0;

    // If all out or match over
    int maxWickets = teamAPlayers.length - 1;
    if (wickets >= maxWickets) return 0.0;
    if (remainingBalls <= 0) return 0.0;

    double probability = 0.5; // Start with 50-50

    // Factor 1: Required Run Rate vs Current Run Rate
    // If CRR > RRR, batting team has advantage
    double rrr = requiredRunRate;
    double crr = currentRunRate;
    if (rrr > 0) {
      double rrRatio = crr / rrr;
      if (rrRatio >= 1.5) {
        probability += 0.25; // Strong batting advantage
      } else if (rrRatio >= 1.2) {
        probability += 0.15; // Good batting advantage
      } else if (rrRatio >= 1.0) {
        probability += 0.08; // Slight batting advantage
      } else if (rrRatio >= 0.8) {
        probability -= 0.08; // Slight bowling advantage
      } else if (rrRatio >= 0.6) {
        probability -= 0.15; // Good bowling advantage
      } else {
        probability -= 0.25; // Strong bowling advantage
      }
    }

    // Factor 2: Wickets in hand
    int wicketsRemaining = maxWickets - wickets;
    double wicketFactor = wicketsRemaining / maxWickets;
    probability += (wicketFactor - 0.5) * 0.3;

    // Factor 3: Runs needed vs balls remaining
    double runsPerBallNeeded = requiredRuns / remainingBalls.toDouble();
    if (runsPerBallNeeded < 0.5) {
      probability += 0.15; // Easy chase
    } else if (runsPerBallNeeded > 2.0) {
      probability -= 0.25; // Very difficult
    } else if (runsPerBallNeeded > 1.5) {
      probability -= 0.15; // Difficult
    } else if (runsPerBallNeeded > 1.0) {
      probability -= 0.05; // Challenging
    }

    // Factor 4: Death overs pressure (last 2 overs)
    if (remainingBalls <= 12 && requiredRuns > 15) {
      probability -= 0.1; // Pressure on batting team
    }

    // Clamp between 0.05 and 0.95 (never show absolute certainty)
    return probability.clamp(0.05, 0.95);
  }

  // Get bowling team win probability
  double get bowlingTeamWinProbability => 1.0 - battingTeamWinProbability;

  // Show exit confirmation dialog
  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Exit Match?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Score:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$runs/$wickets',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text('$completedOvers.$ballsInCurrentOver overs'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your match progress will be lost if you exit now.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Match'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _processBallOutcome(BallOutcome outcome) {
    // Save state BEFORE processing for undo functionality
    String description = _getOutcomeDescription(outcome, 0);
    _saveStateForUndo(outcome, description);

    String currentBatsman = _getCurrentBatsman();
    BatsmanStats batsman = batsmenStats[currentBatsman]!;
    BowlerStats bowler = bowlerStats[currentBowler]!;

    int runsOnThisBall = 0;
    bool isValidDelivery = true;
    bool isWicket = false;

    switch (outcome) {
      case BallOutcome.dot:
        HapticFeedback.selectionClick();
        break;
      case BallOutcome.one:
        HapticFeedback.lightImpact();
        runsOnThisBall = 1;
        break;
      case BallOutcome.two:
        HapticFeedback.mediumImpact();
        runsOnThisBall = 2;
        break;
      case BallOutcome.three:
        HapticFeedback.mediumImpact();
        runsOnThisBall = 3;
        break;
      case BallOutcome.four:
        HapticFeedback.heavyImpact();
        _playRandomAudio(audio4s); // Play 4s audio
        runsOnThisBall = 4;
        break;
      case BallOutcome.six:
        HapticFeedback.heavyImpact();
        _playRandomAudio(audio6s); // Play 6s audio
        runsOnThisBall = 6;
        break;
      case BallOutcome.wide:
        HapticFeedback.vibrate();
        setState(() {
          runs += 1;
          bowler.runs += 1;
          bowler.extras += 1;
        });
        isValidDelivery = false;
        break;
      case BallOutcome.noBall:
        HapticFeedback.vibrate();
        setState(() {
          runs += 1;
          bowler.runs += 1;
          bowler.extras += 1;
        });
        isValidDelivery = false;
        break;
      case BallOutcome.wicket:
        HapticFeedback.heavyImpact();
        _playRandomAudio(audioWickets); // Play wicket audio
        isWicket = true;
        setState(() {
          wickets++;
          bowler.wickets++;
          batsman.isOut = true;
          // Reset partnership on wicket
          partnershipRuns = 0;
          partnershipBalls = 0;
        });
        break;
      case BallOutcome.bye:
        HapticFeedback.lightImpact();
        runsOnThisBall = 1;
        setState(() {
          bowler.extras += 1;
        });
        break;
      case BallOutcome.legBye:
        HapticFeedback.lightImpact();
        runsOnThisBall = 1;
        setState(() {
          bowler.extras += 1;
        });
        break;
      case BallOutcome.runOut:
        HapticFeedback.heavyImpact();
        isWicket = true;
        setState(() {
          wickets++;
          // Run out is NOT credited to bowler
          batsman.isOut = true;
          // Reset partnership on wicket
          partnershipRuns = 0;
          partnershipBalls = 0;
        });
        break;
    }

    if (runsOnThisBall > 0) {
      setState(() {
        runs += runsOnThisBall;
        requiredRuns = targetRuns - runs;
        // Partnership tracking
        partnershipRuns += runsOnThisBall;
        if (outcome != BallOutcome.bye && outcome != BallOutcome.legBye) {
          batsmenStats[currentBatsman]!.runs += runsOnThisBall;
          if (runsOnThisBall == 4) {
            batsmenStats[currentBatsman]!.fours++;
          } else if (runsOnThisBall == 6) {
            batsmenStats[currentBatsman]!.sixes++;
          }
        }
        bowler.runs += runsOnThisBall;
        _checkBattingTeamWin();
      });
    }

    // Only decrement remainingBalls for valid deliveries (FIXED: removed duplicate decrement)
    if (isValidDelivery) {
      setState(() {
        batsmenStats[currentBatsman]!.ballsFaced++;
        bowler.ballsBowled++;
        if (innings == 1) {
          remainingBalls = remainingBalls - 1;
        }
        ballsInCurrentOver++;
        partnershipBalls++;
        if (ballsInCurrentOver == 6) {
          completedOvers++;
          ballsInCurrentOver = 0;
          currentOverOutcomes = [];
          _switchBatsmen();
          _selectBowler();
        }
      });
    }

    if (isValidDelivery ||
        outcome == BallOutcome.wide ||
        outcome == BallOutcome.noBall) {
      setState(() {
        currentOverOutcomes.add(outcome);
      });
    }

    if (runsOnThisBall > 0 && runsOnThisBall % 2 == 1) {
      _switchBatsmen();
    }

    if (isWicket && wickets < 10) {
      _newBatsman();
    }
    if (wickets == (teamAPlayers.length - 1) || completedOvers >= 8) {
      innings++;
      if (innings == 2) {
        _endMatch();
        return;
      }
      _showInningsEndDialog();
    }
    if (innings == 2) {
      _endMatch();
    }
  }

  String _getCurrentBatsman() {
    return striker;
  }

  void _switchBatsmen() {
    setState(() {
      for (var entry in batsmenStats.entries) {
        if (!entry.value.isOut) {
          entry.value.isOnStrike = !entry.value.isOnStrike;
        }
      }
      final notOut = batsmenStats.entries.where((e) => !e.value.isOut).toList();
      if (notOut.length >= 2) {
        String currentStriker = "";
        String currentNonStriker = "";
        for (var entry in notOut) {
          if (entry.value.isOnStrike) {
            currentStriker = entry.key;
          } else {
            currentNonStriker = entry.key;
          }
        }
        if (currentStriker.isNotEmpty && currentNonStriker.isNotEmpty) {
          striker = currentStriker;
          nonStriker = currentNonStriker;
        }
      }
    });
  }

  void _newBatsman() async {
    List availablePlayers = teamAPlayers
        .where((p) =>
            p != striker &&
            p != nonStriker &&
            (!batsmenStats.containsKey(p) || !batsmenStats[p]!.isOut))
        .toList();

    String? nextBatsman = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Select Next Batsman"),
          children: availablePlayers.map((player) {
            return SimpleDialogOption(
              child: Text(player),
              onPressed: () => Navigator.pop(context, player),
            );
          }).toList(),
        );
      },
    );

    if (nextBatsman != null) {
      setState(() {
        String outBatsman = _getCurrentBatsman();
        batsmenStats[nextBatsman] =
            BatsmanStats(name: nextBatsman, isOnStrike: true);

        if (outBatsman == striker) {
          striker = nextBatsman;
        } else if (outBatsman == nonStriker) {
          nonStriker = nextBatsman;
          for (var entry in batsmenStats.entries) {
            if (entry.key == striker) {
              entry.value.isOnStrike = false;
            } else if (entry.key == nextBatsman) {
              entry.value.isOnStrike = true;
            }
          }
          String temp = striker;
          striker = nonStriker;
          nonStriker = temp;
        }
      });
    }
  }

  Future<void> _selectBowler() async {
    String? selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final available = teamBPlayers;
        return SimpleDialog(
          title: const Text("Select Bowler"),
          children: available.map((player) {
            return SimpleDialogOption(
              child: Text(player),
              onPressed: () => Navigator.pop(context, player),
            );
          }).toList(),
        );
      },
    );
    if (selected != null) {
      setState(() {
        currentBowler = selected;
        if (!bowlerStats.containsKey(currentBowler)) {
          bowlerStats[currentBowler] = BowlerStats(name: currentBowler);
        }
      });
    }
  }

  void _endMatch() async {
    _playHornSound(); // Play horn sound on match end
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    for (var entry in batsmenStats.entries) {
      final name = entry.key;
      final stats = entry.value;

      final String? docId = _playerIds[name];

      if (docId != null) {
        // Update directly using ID
        await _firestore.collection('players').doc(docId).update({
          'totalRuns': FieldValue.increment(stats.runs),
          'ballsFaced': FieldValue.increment(stats.ballsFaced),
          'fours': FieldValue.increment(stats.fours),
          'sixes': FieldValue.increment(stats.sixes),
          'totalDismissals': FieldValue.increment(stats.isOut ? 1 : 0),
          'matches': FieldValue.increment(1),
        });
      } else {
        // Fallback to name query if ID missing
        final querySnapshot = await _firestore
            .collection('players')
            .where('playerName', isEqualTo: name)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final docRef = querySnapshot.docs.first.reference;
          await docRef.update({
            'totalRuns': FieldValue.increment(stats.runs),
            'ballsFaced': FieldValue.increment(stats.ballsFaced),
            'fours': FieldValue.increment(stats.fours),
            'sixes': FieldValue.increment(stats.sixes),
            'totalDismissals': FieldValue.increment(stats.isOut ? 1 : 0),
            'matches': FieldValue.increment(1),
          });
        }
      }
    }

    for (var entry in bowlerStats.entries) {
      final name = entry.key;
      final stats = entry.value;

      final String? docId = _playerIds[name];

      // Calculate overs as double (e.g., 6.2 overs = 6 + 2/10)
      double overs = stats.ballsBowled / 6.0;
      final updateData = {
        'ballsBowled': FieldValue.increment(stats.ballsBowled),
        'wickets': FieldValue.increment(stats.wickets),
        'runsConceded': FieldValue.increment(stats.runs),
        'extras': FieldValue.increment(stats.extras),
        'overs': FieldValue.increment(overs),
        'matches': FieldValue.increment(1),
      };

      if (docId != null) {
        await _firestore.collection('players').doc(docId).update(updateData);
      } else {
        final querySnapshot = await _firestore
            .collection('players')
            .where('playerName', isEqualTo: name)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final docRef = querySnapshot.docs.first.reference;
          await docRef.update(updateData);
        }
      }
    }

    String result = getMatchResult(
        runs: runs,
        wickets: wickets,
        targetRuns: targetRuns,
        completedOvers: completedOvers,
        ballsInCurrentOver: ballsInCurrentOver,
        firstInningRuns: firstInningRuns,
        firstInningWickets: firstInningWickets);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("End Match"),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MatchSummaryScreen(
                              teamAName: widget.battingTeam,
                              teamBName: widget.bowlingTeam,
                              target: targetRuns,
                              matchResult: result,
                              teamARuns: firstInningRuns,
                              teamAWickets: firstInningWickets,
                              teamBRuns: runs,
                              teamBWickets: wickets,
                              // Pass match-specific stats
                              batsmenStats: batsmenStats
                                  .map((key, value) => MapEntry(key, {
                                        'runs': value.runs,
                                        'ballsFaced': value.ballsFaced,
                                        'fours': value.fours,
                                        'sixes': value.sixes,
                                        'isOut': value.isOut,
                                      })),
                              bowlerStats: bowlerStats
                                  .map((key, value) => MapEntry(key, {
                                        'wickets': value.wickets,
                                        'ballsBowled': value.ballsBowled,
                                        'runs': value.runs,
                                        'extras': value.extras,
                                      })),
                              teamAPlayers: teamAPlayers.cast<String>(),
                              teamBPlayers: teamBPlayers.cast<String>(),
                            )));
              },
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Go to summary"),
            ),
          ],
        );
      },
    );
  }

  void _showInningsEndDialog() {
    String oversDisplay = "$completedOvers.$ballsInCurrentOver";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Innings Complete'),
          content: Text(
              '${widget.battingTeam} scored $runs/$wickets in $oversDisplay overs'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('EXIT'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetMatch();
              },
              child: const Text('NEW INNINGS'),
            ),
          ],
        );
      },
    );
  }

  String getMatchResult({
    required int runs,
    required int wickets,
    required int targetRuns,
    required int completedOvers,
    required int ballsInCurrentOver,
    required int firstInningRuns,
    required int firstInningWickets,
  }) {
    final int totalBalls = completedOvers * 6 + ballsInCurrentOver;
    final int totalMatchBalls = 48; // 8 overs * 6 balls

    if (runs < targetRuns &&
        (wickets < teamAPlayers.length - 1 && totalBalls < totalMatchBalls)) {
      int runsNeeded = targetRuns - runs;
      int ballsLeft = totalMatchBalls - totalBalls;
      return "Match in progress: $runsNeeded runs needed from $ballsLeft balls.";
    }

    if (runs == targetRuns - 1) {
      return "Match Tied!";
    }

    if (runs >= targetRuns) {
      int wicketsRemaining = teamAPlayers.length - wickets;
      return "${widget.battingTeam} won by $wicketsRemaining wicket(s)!";
    }

    int runDifference = targetRuns - 1 - runs;
    return "${widget.bowlingTeam} won by $runDifference run(s)!";
  }

  void _resetMatch() {
    setState(() {
      isLoading = true;
    });

    // Reset local state only. Do NOT wipe global stats in Firestore.
    setState(() {
      isLoading = false;
      if (innings == 1) {
        // Starting second innings - save first innings data and swap teams
        firstInningRuns = runs;
        firstInningWickets = wickets;
        firstInningBallRemaining =
            (8 * 6) - (completedOvers * 6 + ballsInCurrentOver);

        // Set target: first innings runs + 1
        targetRuns = firstInningRuns + 1;
        requiredRuns = targetRuns;
        remainingBalls = 8 * 6; // Full 8 overs for second innings

        // Swap teams for second innings and remove duplicates
        final temp = teamAPlayers;
        teamAPlayers = teamBPlayers.toSet().toList();
        teamBPlayers = temp.toSet().toList();
      } else {
        // If already in 2nd innings, reset to start
        innings = 0;
        targetRuns = 0;
        requiredRuns = 0;
        remainingBalls = 0;
        firstInningRuns = 0;
        firstInningWickets = 0;
      }

      runs = 0;
      wickets = 0;
      completedOvers = 0;
      ballsInCurrentOver = 0;
      currentOverOutcomes = [];
      ballHistory.clear();

      // DON'T clear stats - accumulate across innings!
      // Stats will be saved to Firebase at match end
      // batsmenStats.clear();  // REMOVED - was causing first innings stats loss
      // bowlerStats.clear();   // REMOVED - was causing first innings stats loss

      // Re-initialize players for current innings (only if not already present)
      if (teamAPlayers.length >= 2 && teamBPlayers.isNotEmpty) {
        striker = teamAPlayers[0];
        nonStriker = teamAPlayers[1];
        currentBowler = teamBPlayers[0];

        // Use putIfAbsent to preserve existing stats
        batsmenStats.putIfAbsent(
            striker, () => BatsmanStats(name: striker, isOnStrike: true));
        batsmenStats.putIfAbsent(nonStriker,
            () => BatsmanStats(name: nonStriker, isOnStrike: false));
        bowlerStats.putIfAbsent(
            currentBowler, () => BowlerStats(name: currentBowler));

        // Update strike status for existing batsmen
        batsmenStats[striker]?.isOnStrike = true;
        batsmenStats[nonStriker]?.isOnStrike = false;
      }
    });
  }

  Color _getOutcomeColor(BallOutcome outcome) {
    switch (outcome) {
      case BallOutcome.dot:
        return Colors.grey[700]!;
      case BallOutcome.one:
      case BallOutcome.two:
      case BallOutcome.three:
        return Colors.blue[700]!;
      case BallOutcome.four:
        return Colors.green[700]!;
      case BallOutcome.six:
        return Colors.purple[700]!;
      case BallOutcome.wide:
      case BallOutcome.noBall:
      case BallOutcome.bye:
      case BallOutcome.legBye:
        return Colors.orange[700]!;
      case BallOutcome.wicket:
        return Colors.red[700]!;
      case BallOutcome.runOut:
        return Colors.red[700]!;
    }
  }

  String _getOutcomeDisplayText(BallOutcome outcome) {
    switch (outcome) {
      case BallOutcome.dot:
        return "0";
      case BallOutcome.one:
        return "1";
      case BallOutcome.two:
        return "2";
      case BallOutcome.three:
        return "3";
      case BallOutcome.four:
        return "4";
      case BallOutcome.six:
        return "6";
      case BallOutcome.wide:
        return "WD";
      case BallOutcome.noBall:
        return "NB";
      case BallOutcome.wicket:
        return "W";
      case BallOutcome.bye:
        return "B";
      case BallOutcome.legBye:
        return "LB";
      case BallOutcome.runOut:
        return "RO";
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldExit = await _showExitConfirmation();
              if (shouldExit && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
              backgroundColor: Colors.grey[100],
              appBar: AppBar(
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final shouldExit = await _showExitConfirmation();
                    if (shouldExit && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Text(
                  '${widget.battingTeam} vs ${widget.bowlingTeam}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 1.2,
                  ),
                ),
                backgroundColor: Colors.blue[900],
                foregroundColor: Colors.white,
                actions: [
                  // Horn Sound Button
                  IconButton(
                    icon: const Icon(Icons.campaign, color: Colors.amber),
                    onPressed: _playHornSound,
                    tooltip: 'Play Horn',
                  ),
                  // Undo Button with badge showing available undos
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo),
                        onPressed:
                            ballHistory.isNotEmpty ? _undoLastBall : null,
                        tooltip: 'Undo Last Ball',
                        color: ballHistory.isNotEmpty
                            ? Colors.white
                            : Colors.white38,
                      ),
                      if (ballHistory.isNotEmpty)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${ballHistory.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _resetMatch,
                    tooltip: 'Reset Match',
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _buildScoreHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildWinProbabilityBar(), // Win probability during chase
                            _buildBatsmenSection(),
                            const SizedBox(height: 8),
                            _buildBowlerSection(),
                            const SizedBox(height: 12),
                            _buildCurrentOverTracker(),
                          ],
                        ),
                      ),
                    ),
                    _buildScoringButtons(),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildScoreHeader() {
    String oversDisplay = "$completedOvers.$ballsInCurrentOver";
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[900]!.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      width: double.infinity,
      child: Column(
        children: [
          Text(
            innings == 0 ? widget.battingTeam : widget.bowlingTeam,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$runs/$wickets",
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white30, width: 1.2),
                ),
                child: Text(
                  "Overs: $oversDisplay",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Run Rate and Partnership Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // CRR
              _buildStatChip(
                label: 'CRR',
                value: currentRunRate.toStringAsFixed(2),
                color: Colors.white24,
              ),
              // Partnership
              _buildStatChip(
                label: 'Partnership',
                value: '$partnershipRuns ($partnershipBalls)',
                color: Colors.green.withOpacity(0.3),
              ),
              // RRR (only in 2nd innings)
              if (innings == 1)
                _buildStatChip(
                  label: 'RRR',
                  value: requiredRunRate.toStringAsFixed(2),
                  color: requiredRunRate > 12
                      ? Colors.red.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.3),
                ),
            ],
          ),
          if (innings == 1)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: requiredRuns <= 0
                      ? Colors.green
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  requiredRuns <= 0
                      ? "🎉 Target Achieved!"
                      : "$requiredRuns runs needed from $remainingBalls balls",
                  style: TextStyle(
                    fontSize: 16,
                    color: requiredRuns <= 0 ? Colors.white : Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      {required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinProbabilityBar() {
    // Only show in 2nd innings when chasing
    if (innings != 1) return const SizedBox.shrink();

    double battingProb = battingTeamWinProbability;
    double bowlingProb = bowlingTeamWinProbability;

    String battingTeam =
        widget.bowlingTeam; // In 2nd innings, original bowling team is batting
    String bowlingTeam =
        widget.battingTeam; // In 2nd innings, original batting team is bowling

    // Determine which team is favored
    bool battingFavored = battingProb > 0.5;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Win Probability',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: battingFavored ? Colors.blue[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  battingFavored
                      ? '$battingTeam favored'
                      : '$bowlingTeam favored',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color:
                        battingFavored ? Colors.blue[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Team names row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                battingTeam,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
              Text(
                bowlingTeam,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Probability bar
          Stack(
            children: [
              // Background
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Batting team section (left)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 16,
                width:
                    MediaQuery.of(context).size.width * 0.8 * battingProb - 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                  ),
                  borderRadius: BorderRadius.horizontal(
                    left: const Radius.circular(8),
                    right: battingProb > 0.95
                        ? const Radius.circular(8)
                        : Radius.zero,
                  ),
                ),
              ),
              // Bowling team section (right) - positioned from right
              Positioned(
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  height: 16,
                  width:
                      (MediaQuery.of(context).size.width * 0.8 * bowlingProb -
                              32)
                          .clamp(0, double.infinity),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400]!, Colors.green[600]!],
                    ),
                    borderRadius: BorderRadius.horizontal(
                      left: bowlingProb > 0.95
                          ? const Radius.circular(8)
                          : Radius.zero,
                      right: const Radius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Percentage row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(battingProb * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              Text(
                '${(bowlingProb * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatsmenSection() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: Colors.blue[100],
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.sports_cricket, size: 22, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "BATSMEN",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                    flex: 3,
                    child: Text("Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text("R",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("B",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("4s",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("6s",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("SR",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
            const Divider(thickness: 1.2),
            _buildBatsmanDropdownRow(striker, true),
            _buildBatsmanDropdownRow(nonStriker, false),
          ],
        ),
      ),
    );
  }

  Widget _buildBatsmanDropdownRow(String batsmanName, bool isStriker) {
    if (!batsmenStats.containsKey(batsmanName)) {
      return const SizedBox.shrink();
    }
    final batsman = batsmenStats[batsmanName]!;
    final strikeRate = batsman.ballsFaced > 0
        ? (batsman.runs / batsman.ballsFaced * 100).toStringAsFixed(1)
        : "0.0";
    final availablePlayers = teamAPlayers
        .where((p) =>
            (!batsmenStats.containsKey(p) || !batsmenStats[p]!.isOut) ||
            p == batsmanName)
        .toSet() // Remove duplicates
        .toList();
    final dropdownValue = availablePlayers.contains(batsmanName)
        ? batsmanName
        : (availablePlayers.isNotEmpty ? availablePlayers.first : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                isStriker
                    ? const Icon(Icons.sports_cricket,
                        size: 18, color: Colors.blue)
                    : const SizedBox(width: 18),
                Flexible(
                  child: DropdownButton<String>(
                    value: dropdownValue,
                    underline: Container(),
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.black87),
                    items: availablePlayers
                        .map<DropdownMenuItem<String>>(
                            (player) => DropdownMenuItem<String>(
                                  value: player,
                                  child: Text(player),
                                ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != batsmanName) {
                        setState(() {
                          if (!batsmenStats.containsKey(value)) {
                            batsmenStats[value] = BatsmanStats(
                                name: value, isOnStrike: isStriker);
                          }
                          if (isStriker) {
                            batsmenStats[batsmanName]!.isOnStrike = false;
                            batsmenStats[value]!.isOnStrike = true;
                            striker = value;
                          } else {
                            batsmenStats[batsmanName]!.isOnStrike = true;
                            batsmenStats[value]!.isOnStrike = false;
                            nonStriker = value;
                          }
                        });
                      }
                    },
                  ),
                ),
                Text(isStriker ? " *" : "",
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
              child: Text("${batsman.runs}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
              child: Text("${batsman.ballsFaced}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
              child: Text("${batsman.fours}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green))),
          Expanded(
              child: Text("${batsman.sixes}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.purple))),
          Expanded(
              child: Text(strikeRate,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.blue))),
        ],
      ),
    );
  }

  Widget _buildBowlerSection() {
    final bowler = bowlerStats[currentBowler]!;
    int bowledOvers = bowler.ballsBowled ~/ 6;
    int bowledBalls = bowler.ballsBowled % 6;
    String oversBowledDisplay = "$bowledOvers.$bowledBalls";

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: Colors.blue[100],
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.sports, size: 22, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "BOWLER",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                    flex: 3,
                    child: Text("Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text("O",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("R",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("W",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    child: Text("Extras",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ],
            ),
            const Divider(thickness: 1.2),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButton(
                    value: currentBowler,
                    underline: Container(),
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.black87),
                    items: teamBPlayers
                        .toSet()
                        .toList() // Remove duplicates
                        .map((player) => DropdownMenuItem(
                              value: player,
                              child: Text(player),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != currentBowler) {
                        setState(() {
                          currentBowler = value as String;
                          if (!bowlerStats.containsKey(currentBowler)) {
                            bowlerStats[currentBowler] =
                                BowlerStats(name: currentBowler);
                          }
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                    child: Text(oversBowledDisplay,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text("${bowler.runs}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(
                    child: Text("${bowler.wickets}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text("${bowler.extras}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentOverTracker() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: Colors.blue[100],
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "THIS OVER",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 14),
            if (currentOverOutcomes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Text("New over starting...",
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: currentOverOutcomes.map((outcome) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _getOutcomeColor(outcome),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _getOutcomeColor(outcome).withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _getOutcomeDisplayText(outcome),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoringButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[100]!.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Run buttons (0-6)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOutcomeButton(
                  BallOutcome.dot, "0", null, const Size(50, 44)),
              _buildOutcomeButton(
                  BallOutcome.one, "1", null, const Size(50, 44)),
              _buildOutcomeButton(
                  BallOutcome.two, "2", null, const Size(50, 44)),
              _buildOutcomeButton(
                  BallOutcome.three, "3", null, const Size(50, 44)),
              _buildOutcomeButton(
                  BallOutcome.four, "4", Colors.green[600], const Size(50, 44)),
              _buildOutcomeButton(
                  BallOutcome.six, "6", Colors.purple[600], const Size(50, 44)),
            ],
          ),
          const SizedBox(height: 8),
          // Extras row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOutcomeButton(
                  BallOutcome.wide, "WD", Colors.orange, const Size(56, 44)),
              _buildOutcomeButton(
                  BallOutcome.noBall, "NB", Colors.orange, const Size(56, 44)),
              _buildOutcomeButton(
                  BallOutcome.bye, "B", Colors.orange[700], const Size(56, 44)),
              _buildOutcomeButton(BallOutcome.legBye, "LB", Colors.orange[700],
                  const Size(56, 44)),
            ],
          ),
          const SizedBox(height: 8),
          // Wickets row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOutcomeButton(BallOutcome.wicket, "WICKET", Colors.red,
                  const Size(100, 44)),
              _buildOutcomeButton(BallOutcome.runOut, "RUN OUT",
                  Colors.red[700], const Size(100, 44)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeButton(BallOutcome outcome, String label,
      [Color? color, Size size = const Size(32, 32)]) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      shadowColor: (color ?? Colors.blue[700])!.withOpacity(0.2),
      color: color ?? Colors.blue[700],
      child: InkWell(
        onTap: () => _processBallOutcome(outcome),
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white.withOpacity(0.2),
        highlightColor: Colors.white.withOpacity(0.1),
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (color ?? Colors.blue[700])!,
                (color ?? Colors.blue[700])!.withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: label.length > 1 ? 12 : 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Enum for ball outcomes
enum BallOutcome {
  dot,
  one,
  two,
  three,
  four,
  six,
  wide,
  noBall,
  wicket,
  bye,
  legBye,
  runOut, // Run out - wicket but not credited to bowler
}

// Class to track batsman statistics
class BatsmanStats {
  String name;
  bool isOnStrike;
  bool isOut = false;
  int runs = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;

  BatsmanStats({required this.name, required this.isOnStrike});
}

// Class to track bowler statistics
class BowlerStats {
  String name;
  int runs = 0;
  int wickets = 0;
  int ballsBowled = 0;
  int extras = 0;

  BowlerStats({required this.name});
}
