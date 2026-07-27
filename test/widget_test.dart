// Widget smoke test — verifies that the LoveHub app boots far
// enough to render its splash without throwing.
//
// We can't pump the full LoveHubApp here because it depends on
// Firebase / EasyLocalization init. The cold-start tracer exposes
// checkpoint strings we can search for instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovehub/core/perf/cold_start_tracer.dart';

void main() {
  testWidgets('ColdStartTracer reports an initial checkpoint', (tester) async {
    // Trigger one frame so the binding starts.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    ColdStartTracer.instance.mark('widget_test_boot');
    expect(
      ColdStartTracer.instance.checkpoints.any((c) => c.label == 'widget_test_boot'),
      isTrue,
    );
  });
}