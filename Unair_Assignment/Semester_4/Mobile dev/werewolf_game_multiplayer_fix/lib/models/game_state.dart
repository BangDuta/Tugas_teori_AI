import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:collection/collection.dart'; // Untuk groupBy dan firstWhereOrNull
import 'player.dart'; // Pastikan player.dart diimpor
import 'dart:math'; // Untuk random role assignment
import 'dart:async'; // Untuk StreamSubscription

// Ini akan menjadi path utama di Realtime Database Anda
const String _GAMES_PATH = 'games';

enum GamePhase {
  lobby,
  night,
  day,
  voting,
  results,
  gameOver,
}

// Definisi kelas GameLog
class GameLog {
  final String message;
  final DateTime timestamp;

  GameLog({
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static GameLog fromJson(Map<dynamic, dynamic> json) {
    return GameLog(
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// Definisi kelas EliminationRecord
class EliminationRecord {
  // Hanya simpan ID, nama, dan peran pemain yang tereliminasi
  // Untuk menghindari nesting Player object yang dalam di Firebase
  final String playerId;
  final String playerName;
  final Role playerRole;
  final int day;
  final String cause;
  final DateTime timestamp;

  EliminationRecord({
    required this.playerId,
    required this.playerName,
    required this.playerRole,
    required this.day,
    required this.cause,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'playerRole': playerRole.name,
      'day': day,
      'cause': cause,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static EliminationRecord fromJson(Map<dynamic, dynamic> json) {
    return EliminationRecord(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      playerRole: Role.values.firstWhere((e) => e.name == json['playerRole']),
      day: json['day'] as int,
      cause: json['cause'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class GameState extends ChangeNotifier {
  // Ini akan menjadi data yang disinkronkan dari Firebase
  GamePhase _currentPhase = GamePhase.lobby;
  List<Player> _players = [];
  Player? _currentPlayer; // Player yang sedang bermain di perangkat ini
  String _gameCode = ''; // Kode game yang unik untuk bergabung
  int _dayCount = 1;
  List<GameLog> _gameLogs = [];
  Player? _selectedPlayer; // Pemain yang dipilih di UI untuk aksi malam/voting

  List<EliminationRecord> _eliminationHistory = [];

  // Data game yang akan disinkronkan ke Firebase
  Map<String, String> _werewolfVotes = {}; // ID werewolf -> ID target
  String? _doctorProtectionTargetId;
  String? _lastDoctorProtectionId; // ID pemain yang terakhir dilindungi dokter (untuk aturan tidak bisa 2 malam berturut-turut)
  Map<String, String> _dayVotes = {}; // ID pemain yang memilih -> ID pemain yang dipilih

  // Firebase Database Reference
  DatabaseReference? _currentGameRef;
  StreamSubscription<DatabaseEvent>? _gameSubscription;

  // --- Constructor ---
  GameState() {
    _gameLogs.add(GameLog(message: 'Aplikasi dimulai. Buat atau gabung game.'));
  }

  // Getters
  GamePhase get currentPhase => _currentPhase;
  List<Player> get players => _players;
  Player? get currentPlayer => _currentPlayer;
  String get gameCode => _gameCode;
  int get dayCount => _dayCount;
  List<GameLog> get gameLogs => _gameLogs;
  Player? get selectedPlayer => _selectedPlayer;
  List<EliminationRecord> get eliminationHistory => _eliminationHistory;


  // --- Metode Manajemen Game (Dipanggil dari UI dan Akan Menulis ke Firebase) ---

  // Membuat game baru
  Future<void> createGame(String hostName) async {
    _gameCode = _generateGameCode(); // Buat kode unik
    _currentGameRef = FirebaseDatabase.instance.ref(_GAMES_PATH).child(_gameCode);

    // Inisialisasi state game awal di Firebase
    await _currentGameRef!.set({
      'phase': GamePhase.lobby.name,
      'players': {}, // Gunakan map untuk players agar mudah diakses berdasarkan ID
      'dayCount': 1,
      'logs': {
        FirebaseDatabase.instance.ref().child(_GAMES_PATH).child(_gameCode).child('logs').push().key!:
            GameLog(message: '$hostName membuat permainan. Menunggu pemain bergabung...').toJson()
      },
      'werewolfVotes': {},
      'doctorProtectionTargetId': null,
      'lastDoctorProtectionId': null,
      'dayVotes': {},
      'eliminationHistory': {}, // Gunakan map untuk eliminationHistory
    });

    // Otomatis bergabung sebagai host
    final hostPlayer = Player(
      id: FirebaseDatabase.instance.ref().child(_GAMES_PATH).child(_gameCode).child('players').push().key!, // ID unik dari Firebase
      name: hostName,
      role: Role.villager, // Peran akan ditetapkan saat game dimulai oleh server
      isHost: true // Tandai sebagai host
    );
    await addPlayer(hostPlayer); // Tambahkan ke Firebase
    _currentPlayer = hostPlayer; // Set host sebagai currentPlayer perangkat ini

    _listenToGameChanges(); // Mulai mendengarkan perubahan dari Firebase
    notifyListeners();
  }

  // Bergabung ke game yang ada
  Future<void> joinGame(String code, String playerName) async {
    _gameCode = code.toUpperCase();
    _currentGameRef = FirebaseDatabase.instance.ref(_GAMES_PATH).child(_gameCode);

    // Cek apakah gameCode ada
    final snapshot = await _currentGameRef!.get();
    if (!snapshot.exists) {
      _addLogToFirebase('Kode permainan $_gameCode tidak ditemukan.');
      _gameCode = ''; // Reset game code jika tidak ditemukan
      notifyListeners();
      return;
    }

    // Buat player baru
    final newPlayer = Player(
      id: FirebaseDatabase.instance.ref().child(_GAMES_PATH).child(_gameCode).child('players').push().key!, // ID unik dari Firebase
      name: playerName,
      role: Role.villager, // Peran akan ditetapkan saat game dimulai oleh server
    );

    // Tambahkan pemain ke daftar di Firebase
    await _currentGameRef!.child('players').child(newPlayer.id).set(newPlayer.toJson());
    await _addLogToFirebase('${playerName} telah bergabung dengan permainan.');

    _currentPlayer = newPlayer; // Set sebagai currentPlayer perangkat ini
    _listenToGameChanges(); // Mulai mendengarkan perubahan dari Firebase
    notifyListeners();
  }

  // Add player (Internal, dipanggil saat create/join)
  Future<void> addPlayer(Player player) async {
    if (_currentGameRef == null) return;
    await _currentGameRef!.child('players').child(player.id).set(player.toJson());
  }

  // Mulai game (Hanya Host yang bisa memanggil ini)
  Future<void> startGame() async {
    if (_currentGameRef == null || _currentPlayer == null || !_currentPlayer!.isHost) return;
    if (_players.length < 4) {
      await _addLogToFirebase('Minimal 4 pemain diperlukan untuk memulai permainan.');
      return;
    }

    await _assignRolesAndStartGameOnFirebase();
  }

  // Memilih pemain (aksi malam atau voting siang)
  Future<void> selectPlayer(Player player) async {
    if (_currentGameRef == null || _currentPlayer == null || !_currentPlayer!.isAlive) return;
    if (!player.isAlive) {
      await _addLogToFirebase('Pemain ${player.name} sudah tereliminasi dan tidak bisa dipilih.');
      _selectedPlayer = null;
      notifyListeners();
      return;
    }

    if (player.id == _currentPlayer!.id) {
      await _addLogToFirebase('Kamu tidak bisa memilih dirimu sendiri untuk aksi ini.');
      _selectedPlayer = null;
      notifyListeners();
      return;
    }

    // Catat pemilihan ini ke Firebase
    if (_currentPhase == GamePhase.night) {
      switch (_currentPlayer!.role) {
        case Role.werewolf:
          await _currentGameRef!.child('werewolfVotes').child(_currentPlayer!.id).set(player.id);
          await _addLogToFirebase('Kamu memilih ${player.name} sebagai target serangan malam ini.');
          break;
        case Role.seer:
          // Aksi Seer adalah instan dan hanya di sisi klien untuk informasi
          final targetPlayer = _players.firstWhereOrNull((p) => p.id == player.id);
          if (targetPlayer != null) {
            final isWerewolf = targetPlayer.role == Role.werewolf;
            await _addLogToFirebase('Kamu menemukan bahwa ${targetPlayer.name} ${isWerewolf ? 'adalah serigala jadian!' : 'bukan serigala jadian.'}');
          }
          _selectedPlayer = null; // Hapus highlight dari UI
          notifyListeners();
          return; // Tidak perlu set _selectedPlayer untuk aksi Firebase
        case Role.doctor:
          if (player.id == _lastDoctorProtectionId) {
            await _addLogToFirebase('Kamu tidak bisa melindungi ${player.name} dua malam berturut-turut.');
            _selectedPlayer = null;
            notifyListeners();
            return;
          }
          await _currentGameRef!.child('doctorProtectionTargetId').set(player.id);
          await _addLogToFirebase('Kamu memilih untuk melindungi ${player.name} malam ini.');
          break;
        case Role.villager:
          await _addLogToFirebase('Sebagai Penduduk Desa, kamu tidak memiliki aksi khusus di malam hari.');
          _selectedPlayer = null;
          notifyListeners();
          return;
      }
    } else if (_currentPhase == GamePhase.voting) {
      await _currentGameRef!.child('dayVotes').child(_currentPlayer!.id).set(player.id);
      await _addLogToFirebase('Kamu telah memilih ${player.name}.');
    }

    _selectedPlayer = player; // Set _selectedPlayer untuk visual di UI
    notifyListeners();
  }

  // Memajukan fase game (Hanya Host yang bisa memanggil ini)
  Future<void> nextPhase() async {
    if (_currentGameRef == null || _currentPlayer == null || !_currentPlayer!.isHost) return;

    if (_currentPhase == GamePhase.gameOver) {
      await resetGame();
      return;
    }

    switch (_currentPhase) {
      case GamePhase.night:
        await _executeNightActionsOnFirebase();
        await _currentGameRef!.child('phase').set(GamePhase.day.name);
        await _currentGameRef!.child('dayCount').set(_dayCount + 1);
        await _addLogToFirebase('Hari ${_dayCount + 1} dimulai. Desa terbangun.');
        break;
      case GamePhase.day:
        await _currentGameRef!.child('phase').set(GamePhase.voting.name);
        await _addLogToFirebase('Saatnya untuk voting. Pilih pemain yang kamu curigai sebagai serigala jadian.');
        break;
      case GamePhase.voting:
        await _processDayVotesOnFirebase();
        await _currentGameRef!.child('phase').set(GamePhase.results.name);
        break;
      case GamePhase.results:
        if (_checkGameOverCondition()) {
          await _currentGameRef!.child('phase').set(GamePhase.gameOver.name);
        } else {
          await _currentGameRef!.child('phase').set(GamePhase.night.name);
          // Day count sudah di-increment di akhir malam, jadi ini tetap _dayCount
          await _addLogToFirebase('Malam tiba pada hari ${_dayCount}. Desa tertidur.');
        }
        break;
      case GamePhase.gameOver:
      case GamePhase.lobby:
        break;
    }
  }

  // Mereset game (Hanya Host yang bisa memanggil ini)
  Future<void> resetGame() async {
    if (_currentGameRef == null || _currentPlayer == null || !_currentPlayer!.isHost) return;

    // Hapus seluruh node game dari database
    await _currentGameRef!.remove();
    _gameSubscription?.cancel(); // Batalkan langganan
    _currentGameRef = null;
    _gameCode = '';

    // Reset state lokal untuk perangkat host
    _currentPhase = GamePhase.lobby;
    _players = [];
    _dayCount = 1;
    _gameLogs = [GameLog(message: 'Permainan direset. Menunggu pemain bergabung.')];
    _selectedPlayer = null;
    _eliminationHistory = [];
    _werewolfVotes = {};
    _doctorProtectionTargetId = null;
    _lastDoctorProtectionId = null;
    _dayVotes = {};
    _currentPlayer = null; // Reset current player for host
    notifyListeners();
  }

  // Metode untuk pemain non-host meninggalkan game
  Future<void> leaveGame() async {
    if (_currentGameRef == null || _currentPlayer == null) return;

    // Hapus pemain ini dari daftar pemain di Firebase
    await _currentGameRef!.child('players').child(_currentPlayer!.id).remove();
    await _addLogToFirebase('${_currentPlayer!.name} telah meninggalkan permainan.');

    _gameSubscription?.cancel(); // Batalkan langganan pemain ini
    _currentGameRef = null; // Putuskan referensi ke game saat ini
    _gameCode = ''; // Kosongkan kode game lokal

    // Reset state lokal untuk perangkat ini
    _currentPhase = GamePhase.lobby;
    _players = []; // Kosongkan daftar pemain lokal
    _dayCount = 1;
    _gameLogs = [GameLog(message: 'Anda telah keluar dari game. Silakan buat atau gabung game lain.')];
    _selectedPlayer = null;
    _eliminationHistory = [];
    _werewolfVotes = {};
    _doctorProtectionTargetId = null;
    _lastDoctorProtectionId = null;
    _dayVotes = {};
    _currentPlayer = null; // Reset currentPlayer perangkat ini
    notifyListeners();
  }


  // --- Metode Sinkronisasi dan Logika Game (Berinteraksi dengan Firebase) ---

  // Mendengarkan perubahan data game dari Firebase
  void _listenToGameChanges() {
    _gameSubscription?.cancel(); // Batalkan langganan lama jika ada
    if (_currentGameRef == null) return;

    _gameSubscription = _currentGameRef!.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        // Game mungkin sudah dihapus atau tidak ada lagi
        _gameLogs.add(GameLog(message: 'Game telah berakhir atau dihapus.'));
        _currentPhase = GamePhase.lobby; // Kembali ke lobby
        _gameSubscription?.cancel();
        _currentGameRef = null;
        _gameCode = '';
        _currentPlayer = null; // Reset _currentPlayer perangkat ini
        notifyListeners();
        return;
      }

      // Update state lokal dari data Firebase
      _currentPhase = GamePhase.values.firstWhere(
        (e) => e.name == data['phase'],
        orElse: () => GamePhase.lobby, // Default jika tidak ditemukan
      );
      _dayCount = data['dayCount'] ?? 1;

      // Pemain
      _players.clear();
      final playersData = data['players'] as Map<dynamic, dynamic>?;
      if (playersData != null) {
        playersData.forEach((id, playerData) {
          _players.add(Player.fromJson(id, playerData as Map<dynamic, dynamic>));
        });
        // Pastikan _currentPlayer di-update dengan data terbaru dari Firebase
        _currentPlayer = _players.firstWhereOrNull((p) => p.id == _currentPlayer?.id);
      }

      // Log Game
      _gameLogs.clear();
      final logsMap = data['logs'] as Map<dynamic, dynamic>?;
      if (logsMap != null) {
        final sortedLogs = logsMap.entries.map((e) => GameLog.fromJson(e.value as Map<dynamic, dynamic>)).toList();
        sortedLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Urutkan berdasarkan waktu
        _gameLogs.addAll(sortedLogs);
      }

      // Riwayat Eliminasi
      _eliminationHistory.clear();
      final elimHistoryMap = data['eliminationHistory'] as Map<dynamic, dynamic>?;
      if (elimHistoryMap != null) {
        final sortedElims = elimHistoryMap.entries.map((e) => EliminationRecord.fromJson(e.value as Map<dynamic, dynamic>)).toList();
        sortedElims.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Urutkan berdasarkan waktu
        _eliminationHistory.addAll(sortedElims);
      }

      // Variabel aksi malam dan voting
      _werewolfVotes = Map<String, String>.from(data['werewolfVotes'] ?? {});
      _doctorProtectionTargetId = data['doctorProtectionTargetId'];
      _lastDoctorProtectionId = data['lastDoctorProtectionId'];
      _dayVotes = Map<String, String>.from(data['dayVotes'] ?? {});

      _selectedPlayer = null; // Clear selection on UI after any phase change
      notifyListeners();
    });
  }

  // Menambahkan log ke Firebase
  Future<void> _addLogToFirebase(String message) async {
    if (_currentGameRef == null) return;
    final log = GameLog(message: message);
    await _currentGameRef!.child('logs').push().set(log.toJson());
  }

  // Penetapan peran dan memulai game di Firebase (Hanya Host)
  Future<void> _assignRolesAndStartGameOnFirebase() async {
    final alivePlayers = _players.where((p) => p.isAlive).toList();
    if (alivePlayers.length < 4) return;

    List<Role> rolesPool = _generateRolesPool(alivePlayers.length);
    rolesPool.shuffle(Random());

    // Update peran pemain di Firebase
    for (int i = 0; i < alivePlayers.length; i++) {
      final playerToUpdate = alivePlayers[i];
      final assignedRole = rolesPool.removeAt(0);
      await _currentGameRef!.child('players').child(playerToUpdate.id).update({
        'role': assignedRole.name,
      });
    }

    // Set fase ke night dan tambahkan log
    await _currentGameRef!.child('phase').set(GamePhase.night.name);
    await _addLogToFirebase('Peran telah ditetapkan. Permainan dimulai!');
  }

  List<Role> _generateRolesPool(int numPlayers) {
    List<Role> roles = [];
    if (numPlayers >= 4 && numPlayers <= 6) {
      roles = [Role.werewolf, Role.seer, Role.doctor];
      while (roles.length < numPlayers) roles.add(Role.villager);
    } else if (numPlayers >= 7 && numPlayers <= 9) {
      roles = [Role.werewolf, Role.werewolf, Role.seer, Role.doctor];
      while (roles.length < numPlayers) roles.add(Role.villager);
    } else if (numPlayers >= 10) {
      roles = [Role.werewolf, Role.werewolf, Role.werewolf, Role.seer, Role.doctor];
      while (roles.length < numPlayers) roles.add(Role.villager);
    }
    return roles;
  }

  // Eksekusi aksi malam di Firebase (Hanya Host)
  Future<void> _executeNightActionsOnFirebase() async {
    String? eliminatedByWerewolfId;

    // Konsensus Serigala
    if (_werewolfVotes.isNotEmpty) {
      final Map<String, int> targetCounts = {};
      _werewolfVotes.values.forEach((targetId) {
        targetCounts[targetId] = (targetCounts[targetId] ?? 0) + 1;
      });

      String? majorityTargetId;
      int maxVotes = 0;
      List<String> tiedTargets = [];

      targetCounts.forEach((targetId, votes) {
        if (votes > maxVotes) {
          maxVotes = votes;
          majorityTargetId = targetId;
          tiedTargets = [targetId];
        } else if (votes == maxVotes) {
          tiedTargets.add(targetId);
        }
      });

      if (tiedTargets.length == 1 && majorityTargetId != null) {
        // Hanya eliminasi jika targetnya hidup
        final werewolfTarget = _players.firstWhereOrNull((p) => p.id == majorityTargetId && p.isAlive);
        if (werewolfTarget != null) {
          if (werewolfTarget.id != _doctorProtectionTargetId) {
            eliminatedByWerewolfId = werewolfTarget.id;
          }
        }
      } else {
        await _addLogToFirebase('Para serigala jadian tidak sepakat. Tidak ada yang tereliminasi oleh serigala malam ini.');
      }
    } else {
      await _addLogToFirebase('Tidak ada serigala jadian yang melakukan serangan malam ini.');
    }

    // Lakukan eliminasi dan update Firebase
    if (eliminatedByWerewolfId != null) {
      final player = _players.firstWhereOrNull((p) => p.id == eliminatedByWerewolfId);
      if (player != null) {
        await _eliminatePlayerOnFirebase(player.id, player.name, player.role, 'Dieliminasi oleh serigala jadian');
        await _addLogToFirebase('${player.name} telah dieliminasi oleh serigala jadian!');
      }
    } else if (_doctorProtectionTargetId != null) {
      final protectedPlayer = _players.firstWhereOrNull((p) => p.id == _doctorProtectionTargetId && p.isAlive);
      if (protectedPlayer != null) {
        await _addLogToFirebase('${protectedPlayer.name} telah diselamatkan oleh dokter malam ini!');
      }
    } else if (_werewolfVotes.isNotEmpty && eliminatedByWerewolfId == null) {
       await _addLogToFirebase('Serigala jadian telah beraksi, tetapi tidak ada eliminasi terjadi.');
    }

    // Reset night action states di Firebase
    await _currentGameRef!.child('werewolfVotes').set({});
    await _currentGameRef!.child('lastDoctorProtectionId').set(_doctorProtectionTargetId); // Simpan untuk aturan dokter
    await _currentGameRef!.child('doctorProtectionTargetId').set(null);
  }

  // Proses voting siang di Firebase (Hanya Host)
  Future<void> _processDayVotesOnFirebase() async {
    String? playerToEliminateId;

    if (_dayVotes.isEmpty) {
      await _addLogToFirebase('Tidak ada suara yang diberikan. Tidak ada yang dieliminasi hari ini.');
    } else {
      final Map<String, int> voteCounts = {};
      _dayVotes.values.forEach((votedPlayerId) {
        voteCounts[votedPlayerId] = (voteCounts[votedPlayerId] ?? 0) + 1;
      });

      String? majorityTargetId;
      int maxVotes = 0;
      List<String> tiedPlayersIds = [];

      voteCounts.forEach((votedPlayerId, count) {
        if (count > maxVotes) {
          maxVotes = count;
          majorityTargetId = votedPlayerId;
          tiedPlayersIds = [votedPlayerId];
        } else if (count == maxVotes) {
          tiedPlayersIds.add(votedPlayerId);
        }
      });

      if (tiedPlayersIds.length > 1) {
        await _addLogToFirebase('Terjadi seri dalam voting dengan ${tiedPlayersIds.length} pemain. Tidak ada yang dieliminasi hari ini.');
      } else if (majorityTargetId != null) {
        final eliminatedPlayer = _players.firstWhereOrNull((p) => p.id == majorityTargetId && p.isAlive);
        if (eliminatedPlayer != null) {
          playerToEliminateId = eliminatedPlayer.id;
          await _eliminatePlayerOnFirebase(eliminatedPlayer.id, eliminatedPlayer.name, eliminatedPlayer.role, 'Dieksekusi oleh desa');
          await _addLogToFirebase('Desa telah memilih untuk mengeliminasi ${eliminatedPlayer.name}. Peran aslinya adalah ${_getRoleName(eliminatedPlayer.role)}.');
        } else {
          await _addLogToFirebase('Pemain yang dipilih sudah tereliminasi atau tidak ditemukan. Tidak ada eliminasi baru hari ini.');
        }
      }
    }

    // Reset day votes di Firebase
    await _currentGameRef!.child('dayVotes').set({});
  }

  // Metode pembantu untuk mengeliminasi pemain di Firebase
  Future<void> _eliminatePlayerOnFirebase(String playerId, String playerName, Role playerRole, String cause) async {
    if (_currentGameRef == null) return;
    await _currentGameRef!.child('players').child(playerId).update({'isAlive': false});

    final record = EliminationRecord(playerId: playerId, playerName: playerName, playerRole: playerRole, day: _dayCount, cause: cause);
    await _currentGameRef!.child('eliminationHistory').push().set(record.toJson());
  }

  bool _checkGameOverCondition() {
    final werewolvesAlive = _players.where((p) => p.role == Role.werewolf && p.isAlive).length;
    final villagersAlive = _players.where((p) => p.role != Role.werewolf && p.isAlive).length;

    if (werewolvesAlive == 0) {
      _addLogToFirebase('Semua serigala jadian telah dieliminasi. Desa menang!');
      return true;
    } else if (werewolvesAlive >= villagersAlive) {
      _addLogToFirebase('Jumlah serigala jadian (${werewolvesAlive}) sama atau lebih banyak dari penduduk desa (${villagersAlive}). Serigala jadian menang!');
      return true;
    }
    return false;
  }

  String _generateGameCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  String _getRoleName(Role role) {
    switch (role) {
      case Role.werewolf: return 'Serigala';
      case Role.seer: return 'Peramal';
      case Role.doctor: return 'Dokter';
      case Role.villager: return 'Penduduk';
    }
  }

  bool get areNightActionsComplete {
    final alivePlayers = _players.where((p) => p.isAlive);
    final werewolves = alivePlayers.where((p) => p.role == Role.werewolf);
    final doctors = alivePlayers.where((p) => p.role == Role.doctor);

    bool allWerewolvesVoted = werewolves.isEmpty || _werewolfVotes.length == werewolves.length;
    bool allDoctorsActed = doctors.isEmpty || _doctorProtectionTargetId != null;

    return allWerewolvesVoted && allDoctorsActed;
  }

  bool get areAllDayVotesCast {
    final alivePlayers = _players.where((p) => p.isAlive);
    return alivePlayers.every((p) => _dayVotes.containsKey(p.id));
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    super.dispose();
  }
}