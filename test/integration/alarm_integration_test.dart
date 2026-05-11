import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/alarm_page.dart';

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (call.method == 'read') return 'test_token';
      return null;
    },
  );
}

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

// id:1 — 미읽음, 비중요, high_risk
// id:2 — 읽음, 중요, keyword
final _mockNotifications = [
  {
    'id': 1,
    'type': 'high_risk',
    'title': '삼성전자 급락 리스크 감지',
    'body': '부정적 뉴스 급증',
    'read': false,
    'star': false,
    'created_at': '2026-04-30T09:00:00',
  },
  {
    'id': 2,
    'type': 'keyword',
    'title': 'NAVER 키워드 급등',
    'body': '관련 언급량 증가',
    'read': true,
    'star': true,
    'created_at': '2026-04-30T08:00:00',
  },
];

Widget _buildApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/news': (_) => const Scaffold(body: Text('news')),
      '/stocks': (_) => const Scaffold(body: Text('stocks')),
    },
    home: const AlarmPage(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockSecureStorage);

  group('AlarmPage 통합 테스트', () {
    testWidgets('탭 전환 플로우: 전체 → 중요 → 읽지 않음 → 긴급/리스크', (tester) async {
      final client = MockClient(
          (req) async => _jsonResponse(_mockNotifications, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 전체 탭: 2개 모두 렌더링
        expect(find.text('삼성전자 급락 리스크 감지'), findsOneWidget);
        expect(find.text('NAVER 키워드 급등'), findsOneWidget);

        // 중요 탭: star=true인 NAVER만
        await tester.tap(find.textContaining('중요'));
        await tester.pumpAndSettle();
        expect(find.text('NAVER 키워드 급등'), findsOneWidget);
        expect(find.text('삼성전자 급락 리스크 감지'), findsNothing);

        // 읽지 않음 탭: read=false인 삼성전자만
        await tester.tap(find.textContaining('읽지 않음'));
        await tester.pumpAndSettle();
        expect(find.text('삼성전자 급락 리스크 감지'), findsOneWidget);
        expect(find.text('NAVER 키워드 급등'), findsNothing);

        // 긴급/리스크 탭: high_risk인 삼성전자만
        await tester.tap(find.textContaining('긴급/리스크'));
        await tester.pumpAndSettle();
        expect(find.text('삼성전자 급락 리스크 감지'), findsOneWidget);
        expect(find.text('NAVER 키워드 급등'), findsNothing);
      }, () => client);
    });

    testWidgets('모두 읽음 버튼 탭 → markAsRead API 호출 → 읽지 않음 카운트 0', (tester) async {
      bool markReadCalled = false;

      final client = MockClient((req) async {
        if (req.url.path.contains('/api/notifications/read') &&
            req.method == 'PATCH') {
          markReadCalled = true;
          return _jsonResponse({'unread_count': 0}, 200);
        }
        return _jsonResponse(_mockNotifications, 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 초기 읽지 않음 카운트 1 확인
        expect(find.textContaining('읽지 않음 (1)'), findsOneWidget);

        await tester.tap(find.text('모두 읽음'));
        await tester.pumpAndSettle();

        expect(markReadCalled, isTrue);
        // 읽지 않음 카운트가 0으로 갱신
        expect(find.textContaining('읽지 않음 (0)'), findsOneWidget);
      }, () => client);
    });

    testWidgets('미읽음 알림 탭 → 상세 페이지 이동 → 뒤로가기 → markAsRead API 호출', (tester) async {
      bool markReadCalled = false;

      final client = MockClient((req) async {
        if (req.url.path.contains('/api/notifications/read') &&
            req.method == 'PATCH') {
          markReadCalled = true;
          return _jsonResponse({'unread_count': 0}, 200);
        }
        return _jsonResponse(_mockNotifications, 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 미읽음 알림(삼성전자) 탭
        await tester.tap(find.text('삼성전자 급락 리스크 감지'));
        await tester.pumpAndSettle();

        // 상세 페이지 이동 확인
        expect(find.byType(AlarmDetailPage), findsOneWidget);

        // 뒤로가기
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // markAsRead API 호출 확인 (미읽음이므로)
        expect(markReadCalled, isTrue);
      }, () => client);
    });

    testWidgets('이미 읽은 알림 탭 → 뒤로가기 → markAsRead API 미호출', (tester) async {
      bool markReadCalled = false;

      final client = MockClient((req) async {
        if (req.url.path.contains('/api/notifications/read') &&
            req.method == 'PATCH') {
          markReadCalled = true;
          return _jsonResponse({'unread_count': 0}, 200);
        }
        return _jsonResponse(_mockNotifications, 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 이미 읽은 알림(NAVER, read: true) 탭
        await tester.tap(find.text('NAVER 키워드 급등'));
        await tester.pumpAndSettle();

        expect(find.byType(AlarmDetailPage), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // read=true이므로 API 미호출
        expect(markReadCalled, isFalse);
      }, () => client);
    });

    testWidgets('모두 읽음 API 실패 → 스낵바 표시', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.contains('/api/notifications/read')) {
          return http.Response('error', 500);
        }
        return _jsonResponse(_mockNotifications, 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('모두 읽음'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
      }, () => client);
    });

    testWidgets('읽지 않은 알림 없을 때 모두 읽음 버튼 탭해도 API 미호출', (tester) async {
      final allRead = [
        {
          'id': 1,
          'type': 'keyword',
          'title': '삼성전자 알림',
          'body': '내용',
          'read': true,
          'star': false,
          'created_at': '2026-04-30T09:00:00',
        },
      ];

      bool markReadCalled = false;
      final client = MockClient((req) async {
        if (req.url.path.contains('/api/notifications/read') &&
            req.method == 'PATCH') {
          markReadCalled = true;
          return _jsonResponse({'unread_count': 0}, 200);
        }
        return _jsonResponse(allRead, 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.textContaining('읽지 않음 (0)'), findsOneWidget);

        // 비활성화된 버튼 탭 → API 미호출
        await tester.tap(find.text('모두 읽음'));
        await tester.pumpAndSettle();

        expect(markReadCalled, isFalse);
      }, () => client);
    });

    testWidgets('탭 전환 후 전체 탭으로 돌아오면 전체 목록 복원', (tester) async {
      final client = MockClient(
          (req) async => _jsonResponse(_mockNotifications, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 중요 탭으로 전환
        await tester.tap(find.textContaining('중요'));
        await tester.pumpAndSettle();
        expect(find.text('삼성전자 급락 리스크 감지'), findsNothing);

        // 전체 탭으로 복귀
        await tester.tap(find.textContaining('전체'));
        await tester.pumpAndSettle();

        // 전체 목록 복원
        expect(find.text('삼성전자 급락 리스크 감지'), findsOneWidget);
        expect(find.text('NAVER 키워드 급등'), findsOneWidget);
      }, () => client);
    });
  });
}
