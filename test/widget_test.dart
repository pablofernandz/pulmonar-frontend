import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_app2/main.dart';

void main() {
  testWidgets('La app arranca y muestra un MaterialApp', (tester) async {
    await tester.pumpWidget(const TfgApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
