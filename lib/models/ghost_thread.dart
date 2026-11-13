/// A thought the user started but has not finished or dismissed yet.
class GhostThread {
  const GhostThread({
    required this.id,
    required this.content,
    required this.createdAt,
    this.context,
    this.resolvedAt,
  });

  /// Stable identifier, generated with `uuid` at capture time.
  final String id;

  /// The raw text the user captured.
  final String content;

  /// When the thought was captured.
  final DateTime createdAt;

  /// Optional snapshot of the context the thought was captured in.
  final String? context;

  /// When the thread was marked as resolved; `null` while it is still open.
  final DateTime? resolvedAt;

  /// Whether the thread is still waiting to be picked back up.
  bool get isOpen => resolvedAt == null;
}
