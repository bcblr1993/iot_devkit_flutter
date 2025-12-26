class ProfileMetadata {
  final String id;
  final String name;
  final DateTime lastModified;

  ProfileMetadata({
    required this.id,
    required this.name,
    required this.lastModified,
  });

  factory ProfileMetadata.fromJson(Map<String, dynamic> json) {
    return ProfileMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastModified': lastModified.toIso8601String(),
    };
  }
}
