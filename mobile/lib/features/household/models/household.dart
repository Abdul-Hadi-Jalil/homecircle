class Household {
  const Household({
    required this.id,
    required this.name,
    required this.role,
    this.description,
    this.memberCount = 1,
  });
  final String id;
  final String name;
  final String role;
  final String? description;
  final int memberCount;

  factory Household.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String;
    if (role != 'admin' && role != 'member') {
      throw const FormatException('Invalid role');
    }
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      role: role,
      description: json['description'] as String?,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'description': description,
    'member_count': memberCount,
  };
}
