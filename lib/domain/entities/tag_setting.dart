class TagSetting {
  final String name;
  final String? color;
  final bool isSecure;
  final bool isSystem;
  final DateTime createdAt;

  const TagSetting({
    required this.name,
    this.color,
    this.isSecure = false,
    this.isSystem = false,
    required this.createdAt,
  });
}
