import 'package:flutter_test/flutter_test.dart';
import 'package:route_gpt/app/app.locator.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('CreateAccountDialogModel Tests -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());
  });
}
