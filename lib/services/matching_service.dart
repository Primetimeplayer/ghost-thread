import 'dart:math' as math;

import '../models/ghost_thread.dart';
import 'context_service.dart';
import 'embedding_service.dart';

/// A ranked thread plus the parts that produced its score.
class ThreadMatch {
  const ThreadMatch({
    required this.thread,
    required this.score,
    required this.embeddingScore,
    required this.contextScore,
    required this.reasons,
  });

  final GhostThread thread;

  /// Combined relevance, 0..1.
  final double score;

  /// Content similarity, 0..1, or `null` when there was no query embedding.
  final double? embeddingScore;

  /// Ambient context similarity, 0..1, or `null` when nothing was comparable.
  final double? contextScore;

  /// Short human-readable explanations, e.g. `same weekday`.
  final List<String> reasons;
}

/// Ranks threads against the current moment.
///
/// Scoring is deliberately simple and explainable:
///
/// * Content: cosine similarity of the query embedding, clamped to 0..1.
/// * Context: weighted average of time-of-day closeness (0.4), same weekday
///   (0.3), battery-level closeness (0.15) and location proximity (0.15).
///   Missing signals are left out instead of counting as a mismatch.
/// * Final score: 0.65 * content + 0.35 * context, renormalized over whichever
///   parts are available.
class MatchingService {
  MatchingService({this.embeddings = const EmbeddingService()});

  final EmbeddingService embeddings;

  static const double embeddingWeight = 0.65;
  static const double contextWeight = 0.35;

  /// Top [limit] active threads for the given [context] and optional
  /// [currentEmbedding], best first. Threads scoring 0 are dropped.
  List<ThreadMatch> rankThreads({
    required List<GhostThread> threads,
    required Map<String, dynamic> context,
    List<double> currentEmbedding = const <double>[],
    int limit = 5,
  }) {
    final matches = <ThreadMatch>[];

    for (final thread in threads) {
      if (!thread.isActive) {
        continue;
      }

      final embeddingScore = currentEmbedding.isEmpty || thread.embedding.isEmpty
          ? null
          : embeddings
                .cosineSimilarity(currentEmbedding, thread.embedding)
                .clamp(0.0, 1.0)
                .toDouble();

      final contextResult = _scoreContext(context, thread.contextAtCreation);
      final score = _combine(embeddingScore, contextResult.score);
      if (score <= 0) {
        continue;
      }

      matches.add(
        ThreadMatch(
          thread: thread,
          score: score,
          embeddingScore: embeddingScore,
          contextScore: contextResult.score,
          reasons: contextResult.reasons,
        ),
      );
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return List<ThreadMatch>.unmodifiable(matches.take(limit));
  }

  ({double? score, List<String> reasons}) _scoreContext(
    Map<String, dynamic> current,
    Map<String, dynamic> saved,
  ) {
    var weighted = 0.0;
    var weight = 0.0;
    final reasons = <String>[];

    final hour = _asInt(current[ContextKeys.hour]);
    final savedHour = _asInt(saved[ContextKeys.hour]);
    if (hour != null && savedHour != null) {
      final difference = (hour - savedHour).abs();
      final distance = math.min(difference, 24 - difference);
      weighted += 0.4 * (1 - distance / 12);
      weight += 0.4;
      if (distance <= 1) {
        reasons.add('same time of day');
      }
    }

    final weekday = _asInt(current[ContextKeys.weekday]);
    final savedWeekday = _asInt(saved[ContextKeys.weekday]);
    if (weekday != null && savedWeekday != null) {
      weighted += 0.3 * (weekday == savedWeekday ? 1 : 0);
      weight += 0.3;
      if (weekday == savedWeekday) {
        reasons.add('same weekday');
      }
    }

    final battery = _asInt(current[ContextKeys.batteryLevel]);
    final savedBattery = _asInt(saved[ContextKeys.batteryLevel]);
    if (battery != null && savedBattery != null) {
      final gap = (battery - savedBattery).abs();
      weighted += 0.15 * (1 - gap / 100).clamp(0.0, 1.0);
      weight += 0.15;
      if (gap <= 15) {
        reasons.add('similar battery level');
      }
    }

    final latitude = _asDouble(current[ContextKeys.latitude]);
    final longitude = _asDouble(current[ContextKeys.longitude]);
    final savedLatitude = _asDouble(saved[ContextKeys.latitude]);
    final savedLongitude = _asDouble(saved[ContextKeys.longitude]);
    if (latitude != null &&
        longitude != null &&
        savedLatitude != null &&
        savedLongitude != null) {
      final distanceKm = _distanceKm(
        latitude,
        longitude,
        savedLatitude,
        savedLongitude,
      );
      weighted += 0.15 * (1 - distanceKm / 10).clamp(0.0, 1.0);
      weight += 0.15;
      if (distanceKm <= 2) {
        reasons.add('nearby');
      }
    }

    if (weight == 0) {
      return (score: null, reasons: reasons);
    }
    return (score: (weighted / weight).clamp(0.0, 1.0), reasons: reasons);
  }

  static double _combine(double? embeddingScore, double? contextScore) {
    if (embeddingScore == null && contextScore == null) {
      return 0;
    }
    if (embeddingScore == null) {
      return contextScore!;
    }
    if (contextScore == null) {
      return embeddingScore;
    }
    return (embeddingScore * embeddingWeight +
            contextScore * contextWeight) /
        (embeddingWeight + contextWeight);
  }

  /// Flat-earth distance, accurate enough for a few kilometres.
  static double _distanceKm(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const kmPerDegreeLatitude = 111.32;
    final deltaLatitude = (latitudeA - latitudeB) * kmPerDegreeLatitude;
    final deltaLongitude =
        (longitudeA - longitudeB) *
        kmPerDegreeLatitude *
        math.cos((latitudeA + latitudeB) / 2 * math.pi / 180);
    return math.sqrt(
      deltaLatitude * deltaLatitude + deltaLongitude * deltaLongitude,
    );
  }

  static int? _asInt(Object? value) => value is num ? value.toInt() : null;

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : null;
}
