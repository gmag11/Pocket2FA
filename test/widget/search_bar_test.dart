import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/search_bar.dart';

import '../helpers/pump.dart';

void main() {
  testWidgets('accepts text, reports changes and clears through the button', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final changes = <String>[];
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await pumpApp(
      tester,
      Scaffold(
        body: HomeSearchBar(
          controller: controller,
          focusNode: focusNode,
          onChanged: changes.add,
        ),
      ),
    );

    expect(find.text('Search'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), 'github');
    await tester.pump();

    expect(controller.text, 'github');
    expect(changes, ['github']);
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(changes.last, isEmpty);
    expect(find.byIcon(Icons.clear), findsNothing);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('renders the dark surface with the dark color scheme', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpApp(
      tester,
      Theme(
        data: ThemeData.dark(),
        child: Scaffold(body: HomeSearchBar(controller: controller)),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(HomeSearchBar),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;

    expect(decoration.color, ThemeData.dark().colorScheme.surfaceContainerHigh);
  });
}
