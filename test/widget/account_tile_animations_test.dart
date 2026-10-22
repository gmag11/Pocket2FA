import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/widgets/account_tile_animations.dart';

void main() {
  testWidgets('starts a controller for the requested period', (tester) async {
    final animations = AccountTileAnimations(vsync: const TestVSync());

    animations.startAnimation(30);
    final controller = animations.animController!;

    expect(controller.duration, const Duration(seconds: 30));
    expect(controller.value, inInclusiveRange(0.0, 1.0));

    animations.dispose();
    expect(animations.animController, isNull);
  });

  testWidgets('replaces the controller when the period changes', (
    tester,
  ) async {
    final animations = AccountTileAnimations(vsync: const TestVSync());

    animations.startAnimation(30);
    final first = animations.animController!;
    animations.startAnimation(60);
    final second = animations.animController!;

    expect(second, isNot(same(first)));
    expect(second.duration, const Duration(seconds: 60));

    animations.dispose();
  });

  testWidgets('falls back to 30 seconds for zero and negative periods', (
    tester,
  ) async {
    final animations = AccountTileAnimations(vsync: const TestVSync());

    animations.startAnimation(0);
    expect(animations.animController!.duration, const Duration(seconds: 30));

    animations.startAnimation(-5);
    expect(animations.animController!.duration, const Duration(seconds: 30));

    animations.dispose();
  });

  testWidgets('stopAnimation clears the controller without disposing twice', (
    tester,
  ) async {
    final animations = AccountTileAnimations(vsync: const TestVSync());

    animations.startAnimation(30);
    animations.stopAnimation();
    expect(animations.animController, isNull);

    animations.stopAnimation();
    animations.dispose();
    expect(animations.animController, isNull);
  });
}
