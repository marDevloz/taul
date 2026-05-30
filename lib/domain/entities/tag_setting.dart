class TagSetting {
  final String name;
  final String? color;
  final bool isSecure;
  final DateTime createdAt;

  const TagSetting({
    required this.name,
    this.color,
    this.isSecure = false,
    required this.createdAt,
  });
}
