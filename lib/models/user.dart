// lib/models/user.dart

class User {
  final int id;
  final String name;
  final String role;
  final String phoneNumber;
  final String? token; // Le JWT (JSON Web Token) - Peut être null

  User({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    this.token, // Changé en optionnel
  });

  // Factory constructor pour créer un objet User à partir du JSON de l'API
  factory User.fromJson(Map<String, dynamic> json) {
    
    // --- CORRECTIONS POUR ROBUSTESSE ---
    // Les champs 'id' et 'name' sont généralement garantis par l'API
    // Les autres champs (role, phoneNumber, token) ne sont pas toujours présents,
    // surtout lors du listage des livreurs.
    
    return User(
      id: (json['id'] as num?)?.toInt() ?? 0, // Sécurisé
      name: json['name'] as String? ?? 'Inconnu', // Sécurisé
      
      // Fournit des valeurs par défaut si les champs sont absents
      role: json['role'] as String? ?? 'livreur', 
      phoneNumber: json['phoneNumber'] as String? ?? 'N/A', 
      token: json['token'] as String?, // Accepte null
    );
  }

  // Convertit l'objet User en JSON (pour le stockage local dans SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phoneNumber': phoneNumber,
      'token': token,
    };
  }
}