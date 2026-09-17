/// Formats [d] as `1d 02:03:04`, `02:03:04` or `03:04`.
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String two(int n) => n.toString().padLeft(2, '0');
  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (days > 0) return '${days}d ${two(hours)}:${two(minutes)}:${two(seconds)}';
  if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}

/// Formats [d] for the `X-Vault-Wrap-TTL` header and `ttl` fields.
String vaultTtl(Duration d) => '${d.inSeconds}s';
