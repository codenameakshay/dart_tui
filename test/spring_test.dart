import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

({double maxPos, double finalPos, double finalVel}) _run(
    double damping, int frames) {
  final s = Spring(fps: 60, frequency: 1, damping: damping);
  var pos = 0.0, vel = 0.0, maxPos = 0.0;
  for (var i = 0; i < frames; i++) {
    (pos, vel) = s.update(pos, vel, 100);
    if (pos > maxPos) maxPos = pos;
  }
  return (maxPos: maxPos, finalPos: pos, finalVel: vel);
}

void main() {
  test('fpsToDelta', () {
    expect(fpsToDelta(60), closeTo(1 / 60, 1e-9));
    expect(fpsToDelta(0), 0);
    expect(fpsToDelta(-5), 0);
  });

  test('converges to the target with velocity decaying', () {
    final r = _run(1.0, 2000);
    expect(r.finalPos, closeTo(100, 1));
    expect(r.finalVel, closeTo(0, 1));
  });

  test('lower damping overshoots more than higher damping', () {
    final under = _run(0.1, 2000);
    final over = _run(2.0, 2000);
    expect(under.maxPos, greaterThan(100)); // under-damped overshoots
    expect(under.maxPos, greaterThan(over.maxPos));
    expect(over.finalPos, closeTo(100, 1));
  });

  test('negative frequency/damping are clamped (no NaN)', () {
    final s = Spring(fps: 60, frequency: -1, damping: -1);
    final (pos, vel) = s.update(0, 0, 100);
    expect(pos.isFinite, isTrue);
    expect(vel.isFinite, isTrue);
  });
}
