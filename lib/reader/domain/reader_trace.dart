/// Opt-in diagnostic events. Disabled in ordinary reading; the probe owns the
/// bounded recorder. Page indices and numeric state only: no URLs/credentials.
final class ReaderTrace {
  static void Function(String stage, int? page, Map<String, Object?> data)?
  sink;
}
