import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

class MatchScoreScreen extends StatefulWidget {
  final int overs;
  final List players1;
  final String matchId;
  const MatchScoreScreen(
      {super.key,
      required this.overs,
      required this.matchId,
      required this.players1});

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  List<String> players = [];
  List<String> bowlers = [];
  int currentOver = 0;
  int currentBall = 0;
  int currentInning = 1;
  int selectedBatsmanIndex = 0;
  int selectedBowlerIndex = 0;

  Map<String, int> playerRuns = {};
  Map<String, List<String>> bowlerBalls = {};
  Map<String, int> bowlerOvers = {};
  Map<String, int> bowlerWickets = {};
  Map<String, double> bowlerEconomy = {};

  bool isLoading = false;

  final List<String> ballOptions = ['1', '2', '3', '4', '6', 'W', 'WID', 'NOB'];
  String? selectedBallOutcome;

  @override
  void initState() {
    super.initState();
    fetchPlayersAndBowlers();
  }

  Future<void> fetchPlayersAndBowlers() async {
    final playerSnapshot =
        await FirebaseFirestore.instance.collection('players').get();

    // Extract names and ensure uniqueness
    final uniqueNames = playerSnapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null || !data.containsKey('name')) {
            return null;
          }
          return data['name'] as String;
        })
        .where((name) => name != null)
        .cast<String>()
        .toSet()
        .toList();

    setState(() {
      players = uniqueNames;
      bowlers = uniqueNames;

      for (var player in players) {
        playerRuns[player] = 0;
      }
      for (var bowler in bowlers) {
        bowlerBalls[bowler] = [];
        bowlerOvers[bowler] = 0;
        bowlerWickets[bowler] = 0;
        bowlerEconomy[bowler] = 0.0;
      }
    });
  }

  Future<void> updateFirebaseData() async {
    final batsman = players[selectedBatsmanIndex];
    final bowler = bowlers[selectedBowlerIndex];

    await FirebaseFirestore.instance.collection('players').doc(batsman).set({
      'name': batsman,
      'id': batsman,
      'runs': playerRuns[batsman],
      'strike rate': (playerRuns[batsman]! /
              ((currentOver * 6 + currentBall) == 0
                  ? 1
                  : (currentOver * 6 + currentBall)))
          .toStringAsFixed(2)
    });

    int totalRuns = bowlerBalls[bowler]!
        .where((e) => ['1', '2', '3', '4', '6'].contains(e))
        .map((e) => int.parse(e))
        .fold(0, (a, b) => a + b);

    int wickets = bowlerBalls[bowler]!.where((e) => e == 'W').length;
    int legalDeliveries =
        bowlerBalls[bowler]!.where((e) => e != 'WID' && e != 'NOB').length;

    double eco = legalDeliveries == 0 ? 0 : (totalRuns / legalDeliveries) * 6;

    await FirebaseFirestore.instance.collection('players').doc(bowler).set({
      'name': bowler,
      'id': bowler,
      'overs bowled': bowlerOvers[bowler],
      'wickets': wickets,
      'economy': eco.toStringAsFixed(2),
    });

    await FirebaseFirestore.instance
        .collection('match')
        .doc(widget.matchId)
        .collection(currentInning == 1 ? 'teamA' : 'teamB')
        .doc('summary')
        .set({
      'total overs': currentOver,
      'runs score': playerRuns.values.reduce((a, b) => a + b),
      'wickets taken': bowlers
          .map((e) => bowlerBalls[e]!.where((e) => e == 'W').length)
          .reduce((a, b) => a + b),
    });
  }

  void nextBall() async {
    if (selectedBallOutcome == null) return;
    final currentBowler = bowlers[selectedBowlerIndex];

    setState(() {
      isLoading = true;
    });

    bowlerBalls[currentBowler]!.add(selectedBallOutcome!);

    if (!['WID', 'NOB'].contains(selectedBallOutcome)) {
      currentBall++;
    }

    // Add runs to player
    if (['1', '2', '3', '4', '6'].contains(selectedBallOutcome)) {
      playerRuns[players[selectedBatsmanIndex]] =
          playerRuns[players[selectedBatsmanIndex]]! +
              int.parse(selectedBallOutcome!);
    }

    if (currentBall >= 6) {
      currentOver++;
      currentBall = 0;
      bowlerOvers[currentBowler] = bowlerOvers[currentBowler]! + 1;
      await updateFirebaseData();
      bowlerBalls[currentBowler] = [];
      selectedBowlerIndex = (selectedBowlerIndex + 1) % bowlers.length;
    }

    if (currentOver >= widget.overs && currentInning == 2) {
      await updateFirebaseData();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Match Over!')));
    } else if (currentOver >= widget.overs) {
      await updateFirebaseData();
      setState(() {
        currentInning = 2;
        currentOver = 0;
        currentBall = 0;
        selectedBowlerIndex = 0;
        selectedBatsmanIndex = 0;
        selectedBallOutcome = null;
        isLoading = false; // ✅ Fix here
      });
      return;
    }

    setState(() {
      selectedBallOutcome = null;
      isLoading = false;
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();

  void _playRandomAudio(String option) async {
    String? path;
    if (option == '4') {
      int index = _random.nextInt(2) + 1; // 1 to 2
      path = 'audios/4s/$index.mp3';
    } else if (option == '6') {
      int index = _random.nextInt(6) + 1; // 1 to 6
      path = 'audios/6s/$index.mp3';
    } else if (option == 'W') {
      int index = _random.nextInt(2) + 1; // 1 to 2
      path = 'audios/wicket/$index.mp3';
    }

    if (path != null) {
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(AssetSource(path));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty || bowlers.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Inning $currentInning - Over ${currentOver + 1}/${widget.overs}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Batsman:'),
                DropdownButton<String>(
                  value: players.contains(players[selectedBatsmanIndex])
                      ? players[selectedBatsmanIndex]
                      : null,
                  items: players.toSet().map((String player) {
                    return DropdownMenuItem<String>(
                      value: player,
                      child: Text('$player (${playerRuns[player]})'),
                    );
                  }).toList(),
                  onChanged: (String? newPlayer) {
                    setState(() {
                      selectedBatsmanIndex = players.indexOf(newPlayer!);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ballOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: selectedBallOutcome == option,
                  onSelected: (_) {
                    setState(() {
                      selectedBallOutcome = option;
                      _playRandomAudio(option);
                    });
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bowler:'),
                DropdownButton<String>(
                  value: bowlers.contains(bowlers[selectedBowlerIndex])
                      ? bowlers[selectedBowlerIndex]
                      : null,
                  items: bowlers.toSet().map((String bowler) {
                    return DropdownMenuItem<String>(
                      value: bowler,
                      child: Text(
                          '$bowler - Balls: ${bowlerBalls[bowler]?.join(", ") ?? ""}'),
                    );
                  }).toList(),
                  onChanged: (String? newBowler) {
                    setState(() {
                      selectedBowlerIndex = bowlers.indexOf(newBowler!);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: nextBall,
                    child: const Text('Next Ball'),
                  ),
          ],
        ),
      ),
    );
  }
}
