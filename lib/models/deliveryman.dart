// lib/models/deliveryman.dart

class Deliveryman {
  final int id;
  final String? name; // Nom complet
  final String? phone;

  Deliveryman({
    required this.id,
    this.name,
    this.phone,
  });

  factory Deliveryman.fromJson(Map<String, dynamic> json) {
    return Deliveryman(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
    );
  }
}