int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class Shop {
  final int id;
  final String name;
  final String phoneNumber;

  Shop({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _parseInt(json['id']) ?? 0,
      name: json['name'] as String? ?? 'N/A',
      phoneNumber: json['phone_number'] as String? ?? 'N/A',
    );
  }
}