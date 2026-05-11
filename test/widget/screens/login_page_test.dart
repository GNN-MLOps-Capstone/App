import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/screens/login_page.dart';

void _mockChannels() {
  final messenger = TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in_v2'),
    (call) async => null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
    dotenv.env['GOOGLE_CLIENT_ID'] = 'test_client_id_for_tests';
  });

  setUp(_mockChannels);

  group('GoogleLoginPage', () {
    testWidgets('로그인 버튼 렌더링', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GoogleLoginPage()),
      );
      await tester.pump();

      expect(find.text('Sign up with Google'), findsOneWidget);
    });

    testWidgets('구글계정으로 로그인 텍스트 렌더링', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GoogleLoginPage()),
      );
      await tester.pump();

      expect(find.text('구글계정으로 로그인'), findsOneWidget);
    });

    testWidgets('첫 번째 온보딩 페이지 텍스트 렌더링', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GoogleLoginPage()),
      );
      await tester.pump();

      expect(find.text('뉴스가 보이니\n마음 놓고 투자!'), findsOneWidget);
    });

    testWidgets('PageView 렌더링', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GoogleLoginPage()),
      );
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('페이지 스와이프 시 다음 온보딩 텍스트로 전환', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GoogleLoginPage()),
      );
      await tester.pump();

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('내 종목 소식\n알아서 챙겨줄게요'), findsOneWidget);
    });

    testWidgets('OutlinedButton.icon 타입 버튼 렌더링', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GoogleLoginPage()),
      );
      await tester.pump();

      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });
}
