import 'dart:convert';

/// A thought the user started but has not finished or dismissed yet.
class GhostThread {
  const GhostThread({
    required this.id,
    required this.content,
    required this.createdAt,
    this.imagePath,
    this.contextAtCreation = const <String, dynamic>{},
    this.embedding = const <double>[],
    this.isActive = true,
    this.lastSurfaced,
    this.surfaceCount = 0,
  });

  /// Stable identifier, generated with `uuid` at capture time.
  final String id;

  /// The raw text the user captured.
  final String content;

  /// Optional path to an image attached at capture time.
  final String? imagePath;

  /// When the thought was captured.
  final DateTime createdAt;

  /// Snapshot of the device context at capture time. Empty for now.
  final Map<String, dynamic> contextAtCreation;

  /// Vector representation used for matching. Empty until embeddings land.
  final List<double> embedding;

  /// Whether the thread still belongs on the home list.
  final bool isActive;

  /// When the thread was last resurfaced by the app.
  final DateTime? lastSurfaced;

  /// How many times the thread has been resurfaced.
  final int surfaceCount;

  GhostThread copyWith({
    String? id,
    String? content,
    String? imagePath,
    DateTime? createdAt,
    Map<String, dynamic>? contextAtCreation,
    List<double>? embedding,
    bool? isActive,
    DateTime? lastSurfaced,
    int? surfaceCount,
  }) {
    return GhostThread(
      id: id ?? this.id,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      contextAtCreation: contextAtCreation ?? this.contextAtCreation,
      embedding: embedding ?? this.embedding,
      isActive: isActive ?? this.isActive,
      lastSurfaced: lastSurfaced ?? this.lastSurfaced,
      surfaceCount: surfaceCount ?? this.surfaceCount,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'content': content,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'contextAtCreation': contextAtCreation,
      'embedding': embedding,
      'isActive': isActive,
      'lastSurfaced': lastSurfaced?.toIso8601String(),
      'surfaceCount': surfaceCount,
    };
  }

  factory GhostThread.fromMap(Map<String, dynamic> map) {
    return GhostThread(
      id: map['id'] as String,
      content: map['content'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      contextAtCreation: Map<String, dynamic>.from(
        map['contextAtCreation'] as Map? ?? const <String, dynamic>{},
      ),
      embedding:
          (map['embedding'] as List?)
              ?.map((value) => (value as num).toDouble())
              .toList(growable: false) ??
          const <double>[],
      isActive: map['isActive'] as bool? ?? true,
      lastSurfaced: map['lastSurfaced'] == null
          ? null
          : DateTime.parse(map['lastSurfaced'] as String),
      surfaceCount: map['surfaceCount'] as int? ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GhostThread.fromJson(String json) {
    return GhostThread.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }
}
