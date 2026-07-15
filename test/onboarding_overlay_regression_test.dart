import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String guidedSrc;
  late String coachmarkSrc;

  setUpAll(() {
    guidedSrc = File(
      'lib/widgets/onboarding/guided_tutorial_overlay.dart',
    ).readAsStringSync();
    coachmarkSrc = File(
      'lib/widgets/onboarding/coachmark_overlay.dart',
    ).readAsStringSync();
  });

  String methodBody(String source, String name) {
    final start = source.indexOf(name);
    expect(start, isNot(-1), reason: 'Expected to find $name');
    final brace = source.indexOf('{', start);
    expect(brace, isNot(-1), reason: 'Expected $name to have a body');

    var depth = 0;
    for (var i = brace; i < source.length; i++) {
      final char = source[i];
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (depth == 0) return source.substring(brace, i + 1);
    }
    fail('Could not find end of $name');
  }

  test('guided overlay stays mounted while spotlight target is measuring', () {
    final buildBody = methodBody(guidedSrc, 'Widget build');
    final measuringBody = methodBody(guidedSrc, 'Widget _measuringScrim');

    expect(
      buildBody,
      contains('if (rect == null || view == null) return _measuringScrim'),
    );
    expect(
      buildBody,
      isNot(
        contains(
          'if (rect == null || view == null) return const SizedBox.shrink()',
        ),
      ),
    );
    expect(measuringBody, contains('HitTestBehavior.opaque'));
    expect(measuringBody, contains('rect: null'));
  });

  test('guided banner sync happens in the controller tick', () {
    final controllerBody = methodBody(guidedSrc, 'void _onController');
    final setStateEnd = controllerBody.indexOf('});');
    final syncBanner = controllerBody.indexOf('_syncBanner();');
    final postFrame = controllerBody.indexOf('addPostFrameCallback');

    expect(syncBanner, greaterThan(setStateEnd));
    expect(syncBanner, lessThan(postFrame));
  });

  test('coachmark ignores stale async measurements after step changes', () {
    final prepareBody = methodBody(coachmarkSrc, 'Future<void> _prepareStep');

    expect(prepareBody, contains('final stepIndex = _index;'));
    expect(prepareBody, contains('if (!mounted || _index != stepIndex)'));
    expect(prepareBody, contains('mounted && _index == stepIndex'));
  });
}
