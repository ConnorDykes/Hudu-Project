String _two(int value) => value.toString().padLeft(2, '0');

/// `HH:mm:ss` of [value] as given (no zone conversion).
String formatClock(DateTime value) =>
    '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';

/// `yyyy-MM-dd HH:mm` in the local zone, for history tables.
String formatLocalMinute(DateTime value) {
  final d = value.toLocal();
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// `yyyy-MM-dd HH:mm:ss UTC`, for audit records the API stores in UTC.
String formatUtcSecond(DateTime value) {
  final d = value.toUtc();
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${formatClock(d)} UTC';
}
