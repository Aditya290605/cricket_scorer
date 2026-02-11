import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:cricket_app/screens/main_screen.dart';
import 'package:flutter/services.dart';

class TossScreen extends StatefulWidget {
  final String teamA;
  final String teamB;
  final String? teamAFlag;
  final String? teamBFlag;
  final List players;

  const TossScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.players,
    this.teamAFlag,
    this.teamBFlag,
  });

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen>
    with SingleTickerProviderStateMixin {
  late String tossWinnerTeam;
  late String otherTeam;
  String? selectedChoice;
  bool isAnimating = true;
  bool showResult = false;
  bool confettiEffect = false;

  // Coin animation
  late AnimationController _animationController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;

  // Team logos opacity animation
  double _teamAOpacity = 1.0;
  double _teamBOpacity = 1.0;

  @override
  void initState() {
    super.initState();

    // Haptic feedback on entry
    HapticFeedback.mediumImpact();

    // Coin flip animation setup with improved physics
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _flipAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 4)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 4, end: 6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_animationController);

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 0.8)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 30,
      ),
    ]).animate(_animationController);

    // Listen to animation status
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Play sound when animation completes
        HapticFeedback.heavyImpact();

        // Determine toss winner
        setState(() {
          // Randomly select the toss winner
          final bool isTeamAWinner = Random().nextBool();
          tossWinnerTeam = isTeamAWinner ? widget.teamA : widget.teamB;
          otherTeam = isTeamAWinner ? widget.teamB : widget.teamA;
          isAnimating = false;

          // Highlight winning team by fading other team
          _teamAOpacity = isTeamAWinner ? 1.0 : 0.4;
          _teamBOpacity = isTeamAWinner ? 0.4 : 1.0;
        });

        // Slight delay before showing the result panel
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            showResult = true;
          });
        });
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectChoice(String choice) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedChoice = choice;
    });
  }

  void _startMatch() async {
    if (selectedChoice != null) {
      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Show confetti effect
      setState(() {
        confettiEffect = true;
      });

      // Fetch players from Firebase where 'team' field is null or doesn't exist
      List<String> playersList = [];
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('players')
            .where('team', isNull: false)
            .get();

        playersList = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            if (kDebugMode) {
              print('Warning: Document ${doc.id} has null data');
            }
            return 'Unknown';
          }
          if (!data.containsKey('name')) {
            if (kDebugMode) {
              print(
                  'Warning: Document ${doc.id} is missing name field. Data: $data');
            }
            return 'Unknown';
          }
          return data['name'] as String;
        }).toList();
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching players: $e');
        }
      }

      // Delay before navigation
      Future.delayed(const Duration(milliseconds: 800), () {
        String battingTeam =
            selectedChoice == 'Bat' ? tossWinnerTeam : otherTeam;
        String bowlingTeam =
            selectedChoice == 'Bowl' ? tossWinnerTeam : otherTeam;

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SimpleCricketScorer(
              players1: playersList,
              battingTeam: battingTeam,
              bowlingTeam: bowlingTeam,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              var begin = const Offset(1.0, 0.0);
              var end = Offset.zero;
              var curve = Curves.easeInOut;
              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'COIN TOSS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[900]?.withOpacity(0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient with cricket pitch overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue[900]!,
                  Colors.blue[800]!,
                  Colors.blue[600]!,
                ],
              ),
            ),
          ),
          // Cricket pitch pattern
          Opacity(
            opacity: 0.1,
            child: Center(
              child: Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.green[800],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildTeamsHeader(),
                  const SizedBox(height: 40),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Only show coin during animation
                        if (isAnimating) _buildCoinAnimation(),

                        // Show toss result panel with animation
                        if (showResult)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: _buildTossResult(),
                          ),

                        // Confetti effect when match starts
                        if (confettiEffect) _buildConfettiEffect(),
                      ],
                    ),
                  ),
                  if (showResult) _buildActionButtons(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsHeader() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Team A
          AnimatedOpacity(
            opacity: _teamAOpacity,
            duration: const Duration(milliseconds: 800),
            child:
                _buildTeamCard(widget.teamA, Colors.blue[700]!, isLeft: true),
          ),

          // VS indicator
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!isAnimating && showResult)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'TOSS COMPLETE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),

          // Team B
          AnimatedOpacity(
            opacity: _teamBOpacity,
            duration: const Duration(milliseconds: 800),
            child:
                _buildTeamCard(widget.teamB, Colors.red[700]!, isLeft: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(String teamName, Color color, {required bool isLeft}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: isLeft && widget.teamAFlag != null
                ? Image.asset(widget.teamAFlag!)
                : !isLeft && widget.teamBFlag != null
                    ? Image.asset(widget.teamBFlag!)
                    : Icon(
                        Icons.sports_cricket,
                        size: 30,
                        color: color,
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          teamName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        // Add win indicator for the winning team
        if (!isAnimating)
          if ((isLeft && widget.teamA == tossWinnerTeam) ||
              (!isLeft && widget.teamB == tossWinnerTeam))
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'WON TOSS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildCoinAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(_flipAnimation.value * pi),
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: _flipAnimation.value % 1 > 0.5
                    ? Colors.amber[300]
                    : Colors.amber[600],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                ],
                gradient: RadialGradient(
                  colors: [
                    Colors.amber[200]!,
                    Colors.amber[400]!,
                    Colors.amber[700]!,
                  ],
                  stops: const [0.2, 0.7, 1.0],
                ),
              ),
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateY(_flipAnimation.value % 1 > 0.5 ? pi : 0),
                  child: Icon(
                    _flipAnimation.value % 1 > 0.5
                        ? Icons.stadium
                        : Icons.sports_cricket,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTossResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'TOSS RESULT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$tossWinnerTeam won the toss',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'What will $tossWinnerTeam choose?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.blue[900],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChoiceButton('Bat', Icons.sports_baseball),
              const SizedBox(width: 30),
              _buildChoiceButton('Bowl', Icons.sports_cricket),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(String choice, IconData icon) {
    final bool isSelected = selectedChoice == choice;

    return GestureDetector(
      onTap: () => _selectChoice(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  )
                ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(height: 12),
            Text(
              choice,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: ElevatedButton(
          onPressed: selectedChoice != null ? _startMatch : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: Colors.green.withOpacity(0.5),
            minimumSize: const Size(double.infinity, 0),
            disabledBackgroundColor: Colors.grey[400],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_cricket, size: 28),
              const SizedBox(width: 12),
              Text(
                selectedChoice != null
                    ? 'START MATCH WITH ${selectedChoice!.toUpperCase()}'
                    : 'SELECT OPTION TO CONTINUE',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfettiEffect() {
    return ConfettiWidget();
  }
}

// Simple Confetti Widget
class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({Key? key}) : super(key: key);

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiPiece> _pieces = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Generate confetti pieces
    for (int i = 0; i < 100; i++) {
      _pieces.add(ConfettiPiece(
        color: _getRandomColor(),
        position: Offset(_random.nextDouble() * 400 - 200, -50),
        velocity:
            Offset(_random.nextDouble() * 6 - 3, _random.nextDouble() * 3 + 3),
        size: _random.nextDouble() * 10 + 5,
        angle: _random.nextDouble() * 2 * pi,
        angularVelocity: _random.nextDouble() * 0.3 - 0.15,
      ));
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getRandomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var piece in _pieces) {
          piece.update(_controller.value);
        }

        return CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: ConfettiPainter(_pieces),
        );
      },
    );
  }
}

class ConfettiPiece {
  Color color;
  Offset position;
  Offset velocity;
  double size;
  double angle;
  double angularVelocity;

  ConfettiPiece({
    required this.color,
    required this.position,
    required this.velocity,
    required this.size,
    required this.angle,
    required this.angularVelocity,
  });

  void update(double progress) {
    position += velocity;
    angle += angularVelocity;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiPiece> pieces;

  ConfettiPainter(this.pieces);

  @override
  void paint(Canvas canvas, Size size) {
    for (var piece in pieces) {
      final paint = Paint()..color = piece.color;

      canvas.save();
      canvas.translate(size.width / 2 + piece.position.dx,
          size.height / 2 + piece.position.dy);
      canvas.rotate(piece.angle);

      // Draw a rectangle for confetti piece
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: piece.size,
          height: piece.size * 1.5,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
