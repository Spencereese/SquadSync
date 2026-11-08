/// PIN WAVE P3C — Fill PIN link-preview / OG title stub.
///
/// Pure-Dart share title: trimmed game + seated/max + sit-here suffix.
/// Middle dot is Unicode `·` (U+00B7). Empty game keeps a leading space.
/// Negative seated clamps to 0; seated above max is literal.
String fillPinLinkPreviewTitle({
  required String game,
  required int seated,
  required int max,
}) {
  final name = game.trim();
  final n = seated < 0 ? 0 : seated;
  return '$name $n/$max · sit here';
}
