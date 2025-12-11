import 'package:flutter/material.dart';
import '../models/game_state.dart'; // Pastikan game_state.dart diimpor (untuk EliminationRecord)
import '../models/player.dart'; // Pastikan player.dart diimpor
import 'package:intl/intl.dart';

class EliminationSidebar extends StatelessWidget {
  final List<EliminationRecord> eliminationHistory;
  final VoidCallback onClose;

  const EliminationSidebar({
    Key? key,
    required this.eliminationHistory,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Eliminasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  color: Colors.white,
                  tooltip: 'Tutup Sidebar',
                ),
              ],
            ),
          ),
          Expanded(
            child: eliminationHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.red.shade300.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada pemain yang tereliminasi',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: eliminationHistory.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final record = eliminationHistory[eliminationHistory.length - 1 - index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getRoleColor(record.playerRole), // Menggunakan playerRole
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getRoleColor(record.playerRole).withOpacity(0.3), // Menggunakan playerRole
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(11),
                                  topRight: Radius.circular(11),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_off,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      record.playerName, // Menggunakan playerName
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(record.playerRole), // Menggunakan playerRole
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getRoleName(record.playerRole), // Menggunakan playerRole
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event,
                                        size: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Hari ${record.day}',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          record.cause,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm:ss').format(record.timestamp),
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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