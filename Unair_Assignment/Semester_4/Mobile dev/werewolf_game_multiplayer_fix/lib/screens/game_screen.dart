import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../widgets/player_avatar.dart';
import '../widgets/role_dialog.dart';
import '../widgets/game_log_widget.dart';
import '../widgets/elimination_sidebar.dart';
import 'lobby_screen.dart';
import 'dart:async'; // Untuk Timer

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _showSidebar = false;
  Timer? _phaseTimer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRoleInfo();
      _startPhaseTimer();
    });
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart timer jika fase berubah
    _startPhaseTimer();
  }

  void _showRoleInfo() {
    final gameState = Provider.of<GameState>(context, listen: false);
    if (gameState.currentPlayer != null) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => RoleDialog(
            player: gameState.currentPlayer!,
            onClose: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        );
      });
    }
  }

  void _startPhaseTimer() {
    _phaseTimer?.cancel();
    final gameState = Provider.of<GameState>(context, listen: false);

    int duration;
    switch (gameState.currentPhase) {
      case GamePhase.night:
        duration = 45;
        break;
      case GamePhase.day:
        duration = 90;
        break;
      case GamePhase.voting:
        duration = 60;
        break;
      default:
        duration = 0;
    }

    if (duration > 0) {
      _secondsRemaining = duration;
      _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          timer.cancel();
          // Hanya host yang dapat memajukan fase secara otomatis setelah timer
          if (gameState.currentPlayer?.isHost == true && _canAdvancePhase(gameState) && gameState.currentPhase != GamePhase.gameOver) {
            gameState.nextPhase();
          }
        }
      });
    } else {
      setState(() {
        _secondsRemaining = 0;
      });
    }
  }

  bool _canAdvancePhase(GameState gameState) {
    switch (gameState.currentPhase) {
      case GamePhase.night:
        return gameState.areNightActionsComplete;
      case GamePhase.day:
        return true;
      case GamePhase.voting:
        return gameState.areAllDayVotesCast;
      case GamePhase.results:
        return true;
      case GamePhase.gameOver:
        return false;
      case GamePhase.lobby:
        return false;
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final currentPhase = gameState.currentPhase;
    final players = gameState.players;
    final currentPlayer = gameState.currentPlayer;
    final dayCount = gameState.dayCount;

    String phaseTitle;
    String phaseDescription;

    switch (currentPhase) {
      case GamePhase.night:
        phaseTitle = 'Fase Malam';
        phaseDescription = 'Desa tertidur. ';
        if (currentPlayer != null && currentPlayer.isAlive) {
          switch (currentPlayer.role) {
            case Role.werewolf:
              phaseDescription += 'Pilih satu pemain untuk diserang oleh serigala jadian. Pilih dengan bijak, dan koordinasikan dengan serigala lain!';
              break;
            case Role.seer:
              phaseDescription += 'Pilih satu pemain untuk diperiksa perannya malam ini.';
              break;
            case Role.doctor:
              phaseDescription += 'Pilih satu pemain untuk dilindungi dari serangan serigala jadian malam ini.';
              break;
            case Role.villager:
              phaseDescription += 'Kamu tidur nyenyak malam ini. Tunggu sampai pagi.';
              break;
          }
        } else if (currentPlayer != null && !currentPlayer.isAlive) {
          phaseDescription += 'Sebagai pemain yang tereliminasi, kamu mengamati dari bayangan.';
        } else {
          phaseDescription += 'Tunggu aksi peran khusus lainnya.';
        }
        break;
      case GamePhase.day:
        phaseTitle = 'Diskusi Siang';
        phaseDescription = 'Desa terbangun. Diskusikan siapa yang mungkin serigala jadian berdasarkan kejadian malam hari dan bukti yang ada. Cari tahu kebenaran!';
        break;
      case GamePhase.voting:
        phaseTitle = 'Fase Voting';
        phaseDescription = 'Waktunya untuk memilih! Pilih pemain yang kamu curigai sebagai serigala jadian. Suaramu penting untuk kelangsungan desa.';
        break;
      case GamePhase.results:
        phaseTitle = 'Hasil Voting';
        phaseDescription = 'Lihat hasil voting hari ini dan siapa yang dieliminasi.';
        break;
      case GamePhase.gameOver:
        phaseTitle = 'Permainan Selesai';
        phaseDescription = 'Permainan telah berakhir. Lihat siapa yang menang!';
        break;
      case GamePhase.lobby:
        phaseTitle = 'Lobby';
        phaseDescription = '';
        break;
    }

    // Hanya currentPlayer yang bisa berinteraksi dengan pemilihan pemain.
    bool canPlayerInteractWithSelection = (currentPhase == GamePhase.night || currentPhase == GamePhase.voting) && currentPlayer != null && currentPlayer.isAlive;


    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentPhase == GamePhase.night
                  ? Colors.indigo.shade900
                  : Colors.red.shade900,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () {
                                setState(() {
                                  _showSidebar = !_showSidebar;
                                });
                              },
                              tooltip: 'Tampilkan Riwayat Eliminasi',
                            ),
                            const Text(
                              'WEREWOLF',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: currentPhase == GamePhase.night
                                    ? Colors.indigo.shade900
                                    : Colors.red.shade900,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    currentPhase == GamePhase.night
                                        ? Icons.nightlight_round
                                        : Icons.wb_sunny,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(phaseTitle),
                                ],
                              ),
                            ),

                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                border: Border.all(color: Colors.grey.shade700),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text('Hari $dayCount'),
                            ),

                            if (currentPlayer != null)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(currentPlayer.role),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child:
                                    Text('Peran: ${_getRoleName(currentPlayer.role)}'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Card(
                            margin: const EdgeInsets.all(16),
                            color: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: currentPhase == GamePhase.night
                                    ? Colors.indigo.shade900
                                    : Colors.red.shade900,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            phaseTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall,
                                          ),
                                          if (_secondsRemaining > 0 &&
                                              currentPhase !=
                                                  GamePhase.gameOver)
                                            Text(
                                              'Sisa waktu: $_secondsRemaining detik',
                                              style: TextStyle(
                                                color: Colors.yellow.shade300,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (currentPhase != GamePhase.gameOver && gameState.currentPlayer?.isHost == true)
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.arrow_forward),
                                          label: const Text('Fase Berikutnya'),
                                          onPressed: _canAdvancePhase(gameState)
                                              ? () {
                                                  gameState.nextPhase();
                                                }
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                currentPhase == GamePhase.night
                                                    ? Colors.indigo.shade800
                                                    : Colors.red.shade800,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    phaseDescription,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        childAspectRatio: 0.8,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                      itemCount: players.length,
                                      itemBuilder: (context, index) {
                                        final player = players[index];
                                        final isSelected = gameState.selectedPlayer?.id == player.id;

                                        bool canTapPlayerAvatar = canPlayerInteractWithSelection && player.id != currentPlayer!.id && player.isAlive;

                                        return GestureDetector(
                                          onTap: canTapPlayerAvatar
                                              ? () => gameState.selectPlayer(player)
                                              : null,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (currentPhase == GamePhase.night
                                                          ? Colors.indigo.shade900
                                                          : Colors.red.shade900)
                                                      .withOpacity(0.7)
                                                  : Colors.black45,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? (currentPhase ==
                                                            GamePhase.night
                                                        ? Colors.indigo.shade300
                                                        : Colors.red.shade300)
                                                    : Colors.grey.shade800,
                                                width: isSelected ? 2 : 1,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: (currentPhase ==
                                                                    GamePhase.night
                                                                ? Colors.indigo
                                                                    .shade900
                                                                : Colors.red
                                                                    .shade900)
                                                            .withOpacity(0.3),
                                                        blurRadius: 8,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                PlayerAvatar(
                                                  player: player,
                                                  size: 60,
                                                  borderColor: isSelected
                                                      ? (currentPhase ==
                                                                  GamePhase.night
                                                              ? Colors.indigo
                                                                  .shade300
                                                              : Colors.red
                                                                  .shade300)
                                                      : null,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  player.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: player.isAlive
                                                        ? Colors.white
                                                        : Colors.grey,
                                                  ),
                                                ),
                                                if (!player.isAlive)
                                                  Container(
                                                    margin: const EdgeInsets.only(
                                                        top: 8),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade900,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text(
                                                      'Tereliminasi',
                                                      style:
                                                          TextStyle(fontSize: 10),
                                                    ),
                                                  ),
                                                if (currentPhase == GamePhase.gameOver)
                                                  Container(
                                                    margin: const EdgeInsets.only(
                                                        top: 8),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: _getRoleColor(
                                                          player.role),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      _getRoleName(player.role),
                                                      style:
                                                          const TextStyle(fontSize: 10),
                                                    ),
                                                  ),
                                                if (currentPhase == GamePhase.voting && player.isAlive && player.id != currentPlayer?.id && currentPlayer?.isAlive == true)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(Icons.how_to_vote, size: 14),
                                                      label: const Text('Vote', style: TextStyle(fontSize: 12)),
                                                      onPressed: canTapPlayerAvatar
                                                          ? () => gameState.selectPlayer(player)
                                                          : null,
                                                      style: ElevatedButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.all(16),
                            color: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: currentPhase == GamePhase.night
                                    ? Colors.indigo.shade900
                                    : Colors.red.shade900,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Log Permainan',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          border: Border.all(
                                              color: Colors.grey.shade700),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${gameState.gameLogs.length}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: GameLogWidget(logs: gameState.gameLogs),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (currentPhase == GamePhase.gameOver)
                    Card(
                      margin: const EdgeInsets.all(16),
                      color: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.red.shade900, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hasil Permainan',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Serigala Jadian',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: players
                                  .where((p) => p.role == Role.werewolf)
                                  .map((player) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade900,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              player.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Penduduk Desa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: players
                                  .where((p) => p.role != Role.werewolf)
                                  .map((player) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(player.role),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person, size: 16),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${player.name} (${_getRoleName(player.role)})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                            if (gameState.currentPlayer?.isHost == true) // Hanya Host yang bisa memulai baru
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Mulai Permainan Baru'),
                                      onPressed: () {
                                        gameState.resetGame();
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (context) => const LobbyScreen(),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              
              if (_showSidebar)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: EliminationSidebar(
                    eliminationHistory: gameState.eliminationHistory,
                    onClose: () {
                      setState(() {
                        _showSidebar = false;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(Role role) {
    switch (role) {
      case Role.werewolf:
        return Colors.red.shade900;
      case Role.seer:
        return Colors.purple.shade900;
      case Role.doctor:
        return Colors.blue.shade900;
      case Role.villager:
        return Colors.green.shade900;
    }
  }

  String _getRoleName(Role role) {
    switch (role) {
      case Role.werewolf:
        return 'Serigala';
      case Role.seer:
        return 'Peramal';
      case Role.doctor:
        return 'Dokter';
      case Role.villager:
        return 'Penduduk';
    }
  }
}