import 'dart:math' as math;

/// Deterministic, offline stand-in for a real text-embedding model.
///
/// Text is tokenized and hashed into a fixed-size vector (the "hashing trick")
/// and then L2-normalized. Identical text always produces an identical vector,
/// and texts that share words produce more similar vectors. The public shape
/// ([embed] plus [cosineSimilarity]) stays the same when a real on-device model
/// replaces the mock later.
class EmbeddingService {
  const EmbeddingService();

  /// Length of every embedding produced by [embed].
  static const int dimensions = 384;

  static final RegExp _tokenPattern = RegExp(r"[a-z0-9']+");

  /// Produces a unit-length embedding for [text].
  List<double> embed(String text) {
    final vector = List<double>.filled(dimensions, 0);

    for (final token in _tokenize(text)) {
      final hash = _fnv1a(token);
      final bucket = hash % dimensions;
      // Signed hashing keeps unrelated collisions from all reinforcing each
      // other.
      final sign = (hash & 0x100) == 0 ? 1.0 : -1.0;
      vector[bucket] += sign;
    }

    final norm = _norm(vector);
    if (norm == 0) {
      return vector;
    }

    for (var i = 0; i < vector.length; i++) {
      vector[i] /= norm;
    }
    return vector;
  }

  /// Cosine similarity between [a] and [b], in the range -1..1.
  ///
  /// Returns 0 when either vector is empty or all zeros, which is what threads
  /// captured before embeddings existed still hold.
  double cosineSimilarity(List<double> a, List<double> b) {
    final length = math.min(a.length, b.length);
    if (length == 0) {
      return 0;
    }

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) {
      return 0;
    }
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  static double _norm(List<double> vector) {
    var sum = 0.0;
    for (final value in vector) {
      sum += value * value;
    }
    return math.sqrt(sum);
  }

  static Iterable<String> _tokenize(String text) {
    return _tokenPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0)!)
        .where((token) => token.length > 1);
  }

  static int _fnv1a(String token) {
    var hash = 0x811c9dc5;
    for (final unit in token.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
