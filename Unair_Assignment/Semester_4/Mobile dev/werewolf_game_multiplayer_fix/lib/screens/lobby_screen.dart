import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'game_screen.dart';
import '../widgets/player_avatar.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({Key? key}) : super(key: key);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gameCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _gameCodeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final players = gameState.players;

    bool canCreateOrJoin = _nameController.text.trim().isNotEmpty && gameState.gameCode.isEmpty;
    bool canJoinWithCode = canCreateOrJoin && _gameCodeController.text.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade900,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'WEREWOLF',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'PERMAINAN SOSIAL DEDUKSI',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade200,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kamu',
                    hintText: 'Masukkan nama kamu',
                    prefixIcon: Icon(Icons.person),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: _gameCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Permainan (untuk bergabung)',
                    hintText: 'Misal: WXYZ123',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 24),

                if (gameState.gameCode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade800, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kode Permainan Anda',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                gameState.gameCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Bagikan kode ini dengan teman untuk bergabung dengan permainan kamu',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                Text(
                  'Pemain (${players.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: players.isEmpty && gameState.gameCode.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.red.shade300.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum ada pemain yang bergabung',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: players.length,
                          itemBuilder: (context, index) {
                            final player = players[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade900.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  PlayerAvatar(player: player),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${player.name} ${player.isHost ? '(Host)' : ''}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Game'),
                        onPressed: canCreateOrJoin
                            ? () async {
                                await gameState.createGame(_nameController.text.trim());
                                if (gameState.gameCode.isNotEmpty) {
                                  _showSnackBar('Game dibuat! Kode: ${gameState.gameCode}');
                                } else {
                                  _showSnackBar('Gagal membuat game. Coba lagi.');
                                }
                                setState(() {});
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Gabung Game'),
                        onPressed: canJoinWithCode
                            ? () async {
                                await gameState.joinGame(_gameCodeController.text.trim(), _nameController.text.trim());
                                if (gameState.gameCode.isNotEmpty) {
                                   _showSnackBar('Bergabung dengan game ${gameState.gameCode}!');
                                } else {
                                  _showSnackBar('Gagal bergabung. Pastikan kode game benar.');
                                }
                                setState(() {});
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (gameState.currentPlayer != null && gameState.currentPlayer!.isHost && gameState.gameCode.isNotEmpty && gameState.currentPhase == GamePhase.lobby)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Mulai Permainan'),
                    onPressed: players.length < 4
                        ? null
                        : () {
                            gameState.startGame();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const GameScreen(),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red.shade800,
                    ),
                  ),

                if (gameState.currentPlayer != null && gameState.gameCode.isNotEmpty && !gameState.currentPlayer!.isHost && gameState.currentPhase == GamePhase.lobby)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pending),
                    label: const Text('Menunggu Host Memulai...'),
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),

                if (gameState.gameCode.isNotEmpty && gameState.currentPhase != GamePhase.lobby && gameState.currentPlayer != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.gamepad),
                    label: const Text('Lanjutkan ke Game'),
                    onPressed: () {
                       Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const GameScreen(),
                          ),
                        );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  ),
                
                if (gameState.gameCode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Keluar Game'),
                      onPressed: () {
                        if (gameState.currentPlayer?.isHost == true) {
                          gameState.resetGame();
                          _showSnackBar('Game telah dihapus.');
                        } else {
                          gameState.leaveGame();
                          _showSnackBar('Anda telah keluar dari game.');
                        }
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepOrange.shade900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}