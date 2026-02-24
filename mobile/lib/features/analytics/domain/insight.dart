class Insight {
  final int id;
  final String type; // trend, anomaly, budget, duplicate
  final String title;
  final String message;
  final Map<String, dynamic>? metadata;
  final DateTime generatedAt;

  Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.metadata,
    required this.generatedAt,
  });

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      message: json['message'],
      metadata: json['metadata'],
      generatedAt: DateTime.parse(json['generated_at']),
    );
  }
}
