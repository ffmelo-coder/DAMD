DateTime? parseUpdatedAt(dynamic value) {
  if (value == null) return null;
  try {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt;

      final maybeNum = int.tryParse(value);
      if (maybeNum != null)
        return DateTime.fromMillisecondsSinceEpoch(maybeNum);
    }
  } catch (e) {}
  return null;
}

String normalizeUpdatedAtToIso(dynamic value) {
  final dt = parseUpdatedAt(value);
  return dt?.toIso8601String() ?? '';
}
