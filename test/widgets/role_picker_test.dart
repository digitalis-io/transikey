import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/widgets/role_picker.dart';

void main() {
  Future<List<(String, String)>> pump(WidgetTester tester) async {
    final picked = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RolePicker(
            groups: const AsyncData([RoleGroup(name: 'database')]),
            selected: null,
            onSelected: (g, r) => picked.add((g, r)),
            onRefresh: () {},
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('a typed role is selected without pressing Enter', (
    tester,
  ) async {
    final picked = await pump(tester);
    await tester.enterText(find.byType(TextField), ' readonly ');
    expect(picked, isEmpty);
    await tester.pump(const Duration(milliseconds: 500));
    expect(picked, [('database', 'readonly')]);
  });

  testWidgets('a blank role selects nothing', (tester) async {
    final picked = await pump(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump(const Duration(milliseconds: 500));
    expect(picked, isEmpty);
  });

  testWidgets('Enter selects at once and only once', (tester) async {
    final picked = await pump(tester);
    await tester.enterText(find.byType(TextField), 'readonly');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 500));
    expect(picked, [('database', 'readonly')]);
  });
}
