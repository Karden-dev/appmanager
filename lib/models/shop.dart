// lib/models/shop.dart
// (Modèle créé pour résoudre les erreurs de getter)

class Shop {
  final int id;
  final String name;
  final String phone;   // AJOUTÉ/CONFIRMÉ
  final String address; // AJOUTÉ/CONFIRMÉ
  final String? city;
  final String? notes;

  Shop({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.city,
    this.notes,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'N/A',
      phone: json['phone'] as String? ?? 'N/A', // Mapping
      address: json['address'] as String? ?? 'N/A', // Mapping
      city: json['city'] as String?,
      notes: json['notes'] as String?,
    );
  }
}