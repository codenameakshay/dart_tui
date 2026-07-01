import 'dart:math' as math;

/// Seconds-per-frame for a given frame rate. Returns 0 for non-positive [fps].
double fpsToDelta(num fps) => fps <= 0 ? 0 : 1 / fps;

/// A damped-harmonic-oscillator for smooth, eased motion of a scalar value,
/// inspired by Charm's [harmonica](https://github.com/charmbracelet/harmonica).
///
/// Integrated with stable semi-implicit (symplectic) Euler — well-behaved for
/// terminal animation at typical frame rates. Use it to ease a progress value,
/// a scroll offset, or any number toward a moving target one frame at a time.
///
/// ```dart
/// final spring = Spring(fps: 60, frequency: 6, damping: 1);
/// var (pos, vel) = (0.0, 0.0);
/// // each TickMsg:
/// (pos, vel) = spring.update(pos, vel, target);
/// ```
///
/// - [frequency] (Hz) controls how quickly it moves toward the target.
/// - [damping] is the damping ratio: `< 1` under-damped (overshoots and
///   oscillates), `1` critically damped, `> 1` over-damped (no overshoot).
final class Spring {
  Spring({
    required num fps,
    required double frequency,
    required double damping,
  })  : _dt = fpsToDelta(fps),
        _angularFreq = 2 * math.pi * (frequency < 0 ? 0 : frequency),
        _damping = damping < 0 ? 0 : damping;

  final double _dt;
  final double _angularFreq;
  final double _damping;

  /// Advance one frame: given the current [pos] and [vel] and the [target],
  /// returns the next `(position, velocity)`.
  (double, double) update(double pos, double vel, double target) {
    final f = _angularFreq;
    final accel = -f * f * (pos - target) - 2 * _damping * f * vel;
    final newVel = vel + accel * _dt;
    final newPos = pos + newVel * _dt;
    return (newPos, newVel);
  }
}
