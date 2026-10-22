import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/home_header_animation.dart';

Future<void> _pumpList(
  WidgetTester tester,
  HomeHeaderAnimation animation, {
  required double height,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: height,
          child: ListView.builder(
            controller: animation.listScrollController,
            itemCount: 20,
            itemBuilder: (context, index) =>
                SizedBox(height: 70, child: Text('row $index')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('initializes and hides then shows the header on scroll', (
    tester,
  ) async {
    final animation = HomeHeaderAnimation();
    var disposed = false;
    addTearDown(() {
      if (!disposed) animation.dispose();
    });
    animation.initialize(const TestVSync());

    expect(animation.headerController.value, 1.0);
    expect(animation.headerSlide.value, Offset.zero);
    expect(animation.headerSizeFactor.value, 1.0);
    expect(animation.listScrollController, isNotNull);

    await _pumpList(tester, animation, height: 200);
    expect(
      animation.listScrollController.position.viewportDimension,
      lessThan(280),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.headerController.value, lessThan(1.0));

    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.headerController.value, greaterThan(0.0));

    await tester.pumpWidget(const SizedBox());
    animation.dispose();
    disposed = true;
  });

  testWidgets('keeps the header visible when the viewport is tall', (
    tester,
  ) async {
    final animation = HomeHeaderAnimation();
    var disposed = false;
    addTearDown(() {
      if (!disposed) animation.dispose();
    });
    animation.initialize(const TestVSync());

    await _pumpList(tester, animation, height: 400);
    expect(
      animation.listScrollController.position.viewportDimension,
      greaterThanOrEqualTo(280),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(animation.headerController.value, 1.0);

    await tester.pumpWidget(const SizedBox());
    animation.dispose();
    disposed = true;
  });

  testWidgets('disposes the scroll listener and animation controller', (
    tester,
  ) async {
    final animation = HomeHeaderAnimation();
    animation.initialize(const TestVSync());
    await _pumpList(tester, animation, height: 200);

    await tester.pumpWidget(const SizedBox());
    animation.dispose();

    expect(tester.takeException(), isNull);
  });
}
