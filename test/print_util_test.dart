import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_util/print_util.dart';

void main() {
  const MethodChannel channel = MethodChannel('print_util');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await PrintUtil.platformVersion, '42');
  });
}
