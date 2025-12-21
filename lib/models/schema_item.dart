class SchemaItem {
  final String name;
  final String type; // 'float', 'int', 'string', 'bool'

  SchemaItem({required this.name, required this.type});

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
  };
}
