// lib/models/user.dart

class User {
  final int id;
  final String name;
  final String role;
  final String phoneNumber;
  final String? token; // <-- MODIFIÉ : Token rendu optionnel

  User({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    this.token, // <-- MODIFIÉ : Peut être null
  });

  // Factory constructor pour créer un objet User à partir du JSON de l'API
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0, // Sécurité supplémentaire
      name: json['name'] as String? ?? 'Inconnu',
      role: json['role'] as String? ?? 'user',
      // Gestion de différentes clés possibles pour le téléphone selon l'API
      phoneNumber: (json['phoneNumber'] ?? json['phone']) as String? ?? '',
      token: json['token'] as String?, // <-- MODIFIÉ : Accepte null
    );
  }

  // Convertit l'objet User en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phoneNumber': phoneNumber,
      'token': token,
    };
  }
  
  // Helper pour l'affichage dans l'Autocomplete
  @override
  String toString() => name;
}