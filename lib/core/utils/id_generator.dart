import 'dart:math';

/// Collision-resistant unique ID generator.
///
/// The previous approach used `DateTime.now().millisecondsSinceEpoch` (and
/// `+ 1` for the AI reply), which collides when two nodes are created within
/// the same millisecond — likely on fast devices during rapid branching.
///
/// This combines microsecond time, a process-wide monotonic counter, and a
/// random suffix so every generated ID is unique even within the same tick.
class IdGenerator {
  static int _counter = 0;
  static final Random _random = Random();

  static String generate() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final count = _counter++;
    final rand = _random.nextInt(1 << 31);
    return '${ts}_${count}_$rand';
  }
}
