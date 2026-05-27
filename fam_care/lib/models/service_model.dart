class ServiceModel {
  final String id;
  final String name;
  final int durationMinutes;
  final double price;
  final String description;
  final bool isActive;

  ServiceModel({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    required this.description,
    required this.isActive,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> j) => ServiceModel(
    id:              j['id'] as String,
    name:            j['name'] as String,
    durationMinutes: j['duration_minutes'] as int,
    price:           double.parse(j['price'].toString()),
    description:     j['description'] as String? ?? '',
    isActive:        j['is_active'] as bool? ?? true,
  );
}
