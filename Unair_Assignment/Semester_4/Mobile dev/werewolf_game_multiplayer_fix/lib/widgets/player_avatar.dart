import 'package:flutter/material.dart';
import '../models/player.dart'; // Pastikan player.dart diimpor

class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double size;
  final Color? borderColor;

  const PlayerAvatar({
    Key? key,
    required this.player,
    this.size = 40,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: borderColor != null ? 2 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: player.isAlive
          ? _getRoleColor(player.role).withOpacity(0.3)
          : Colors.grey.shade800,
        backgroundImage: player.avatarUrl != null ? NetworkImage(player.avatarUrl!) : null,
        child: player.avatarUrl == null
            ? Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: size / 2.5,
                  fontWeight: FontWeight.bold,
                  color: player.isAlive ? Colors.white : Colors.grey,
                ),
              )
            : null,
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
}