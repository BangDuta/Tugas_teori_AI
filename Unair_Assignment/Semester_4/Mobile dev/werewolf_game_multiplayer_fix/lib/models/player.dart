import 'package:flutter/material.dart'; // Tambahkan ini jika belum ada (untuk IconData di getRoleIcon)

enum Role {
  werewolf,
  villager,
  seer,
  doctor,
}

class Player {
  final String id;
  final String name;
  final Role role;
  final bool isAlive;
  final String? avatarUrl;
  final bool isHost; // <--- PROPERTI BARU

  const Player({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.avatarUrl,
    this.isHost = false, // <--- DEFAULT FALSE
  });

  Player copyWith({
    String? id,
    String? name,
    Role? role,
    bool? isAlive,
    String? avatarUrl,
    bool? isHost, // <--- PROPERTI BARU DI COPYWITH
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost, // <--- PROPERTI BARU DI COPYWITH
    );
  }

  // Metode toJson() untuk Firebase Realtime Database
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role.name, // Simpan enum sebagai string
      'isAlive': isAlive,
      'avatarUrl': avatarUrl,
      'isHost': isHost,
    };
  }

  // Metode fromJson() untuk membaca dari Firebase Realtime Database
  // Menerima ID sebagai argumen terpisah karena ID adalah key di Firebase
  static Player fromJson(String id, Map<dynamic, dynamic> json) {
    return Player(
      id: id,
      name: json['name'] as String,
      role: Role.values.firstWhere((e) => e.name == json['role']),
      isAlive: json['isAlive'] as bool,
      avatarUrl: json['avatarUrl'] as String?,
      isHost: json['isHost'] as bool? ?? false, // Tangani null jika properti belum ada di Firebase
    );
  }

  static String getRoleDescription(Role role) {
    switch (role) {
      case Role.werewolf:
        return 'Setiap malam, pilih satu penduduk desa untuk dieliminasi. Bekerja sama dengan serigala jadian lainnya untuk tetap tidak terdeteksi.';
      case Role.villager:
        return 'Bekerja sama dengan penduduk desa lainnya untuk mengidentifikasi dan mengeliminasi serigala jadian melalui voting harian.';
      case Role.seer:
        return 'Setiap malam, kamu dapat memeriksa satu pemain untuk menentukan apakah mereka serigala jadian atau bukan.';
      case Role.doctor:
        return 'Setiap malam, pilih satu pemain untuk dilindungi dari serangan serigala jadian.';
    }
  }

  // Helper untuk mendapatkan ikon peran (opsional, bisa digunakan di RoleDialog atau PlayerAvatar)
  IconData getRoleIcon() {
    switch (role) {
      case Role.werewolf: return Icons.pets;
      case Role.seer: return Icons.remove_red_eye;
      case Role.doctor: return Icons.medical_services;
      case Role.villager: return Icons.person;
    }
  }
}