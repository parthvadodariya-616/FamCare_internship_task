class CaregiverModel {
  final String id;
  final String name;
  final String email;
  final String phone;

  CaregiverModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory CaregiverModel.fromJson(Map<String, dynamic> j) => CaregiverModel(
    id:    j['id']    as String,
    name:  j['name']  as String,
    email: j['email'] as String,
    phone: j['phone'] as String,
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}
