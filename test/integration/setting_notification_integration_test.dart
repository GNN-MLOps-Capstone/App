import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/setting_page.dart';

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (call.method == 'read') return 'test_token';
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in_v2'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.onesignal.flutter'),
    (call) async => null,
  );
}

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

final _mockProfile = {
  'id': 1,
  'google_id': 'google_abc',
  'email': 'test@gmail.com',
  'nickname': '홍길동',
  'img_url': null,
};

// risk_only:true, positive_only:false, interest_only:true, night:false
// → _allPush = false (positive_only가 false이므로)
final _mockSettings = {
  'push': false,
  'risk_only': true,
  'positive_only': false,
  'interest_only': true,
  'night_push_prohibit': false,
  'dnd_start': '23:00:00',
  'dnd_finish': '07:00:00',
};

MockClient _buildDefaultClient() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/api/users/profile')) {
      return _jsonResponse(_mockProfile, 200);
    }
    if (path.contains('/api/users/settings')) {
      if (request.method == 'PATCH') return _jsonResponse(_mockSettings, 200);
      return _jsonResponse(_mockSettings, 200);
    }
    return http.Response('{}', 200);
  });
}

Widget _buildApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/news': (_) => const Scaffold(body: Text('news')),
      '/stock': (_) => const Scaffold(body: Text('stock')),
      '/login': (_) => const Scaffold(body: Text('login')),
    },
    home: const SettingPage(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockChannels);

  group('SettingPage 알림 설정 통합 테스트', () {
    testWidgets('설정 로드 → 스위치 상태 반영 (risk:ON, 호재:OFF, 관심:ON)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Switch 4개: 앱 전체 푸시 / 리스크 / 호재 / 관심 종목
        final switches =
            tester.widgetList<Switch>(find.byType(Switch)).toList();
        expect(switches.length, greaterThanOrEqualTo(4));

        // _allPush = risk(true) && goodNews(false) && favorite(true) = false
        expect(switches[0].value, isFalse); // 앱 전체 푸시
        expect(switches[1].value, isTrue);  // 리스크 알림
        expect(switches[2].value, isFalse); // 호재 알림
        expect(switches[3].value, isTrue);  // 관심 종목 알림
      }, _buildDefaultClient);
    });

    testWidgets('호재 알림 스위치 ON → updateSettings PATCH 호출 → 상태 갱신', (tester) async {
      bool updateCalled = false;
      Map<String, dynamic>? sentBody;

      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/api/users/profile')) {
          return _jsonResponse(_mockProfile, 200);
        }
        if (path.contains('/api/users/settings')) {
          if (request.method == 'GET') return _jsonResponse(_mockSettings, 200);
          if (request.method == 'PATCH') {
            updateCalled = true;
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse({
              ..._mockSettings,
              'positive_only': true,
            }, 200);
          }
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 호재 알림 (index 2) 현재 OFF 확인
        expect(
          tester.widgetList<Switch>(find.byType(Switch)).toList()[2].value,
          isFalse,
        );

        // 호재 알림 스위치 탭
        await tester.tap(find.byType(Switch).at(2));
        await tester.pumpAndSettle();

        expect(updateCalled, isTrue);
        expect(sentBody?['positive_only'], isTrue);

        // UI에서 호재 알림 스위치 ON 확인
        expect(
          tester.widgetList<Switch>(find.byType(Switch)).toList()[2].value,
          isTrue,
        );
      }, () => client);
    });

    testWidgets('앱 전체 푸시 스위치 ON → 리스크·호재·관심 종목 모두 ON', (tester) async {
      final settingsAllOff = {
        'push': false,
        'risk_only': false,
        'positive_only': false,
        'interest_only': false,
        'night_push_prohibit': false,
        'dnd_start': '23:00:00',
        'dnd_finish': '07:00:00',
      };

      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/api/users/profile')) {
          return _jsonResponse(_mockProfile, 200);
        }
        if (path.contains('/api/users/settings')) {
          return _jsonResponse(settingsAllOff, 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 모든 스위치 OFF 확인
        var switches =
            tester.widgetList<Switch>(find.byType(Switch)).toList();
        for (final s in switches.take(4)) {
          expect(s.value, isFalse);
        }

        // 앱 전체 푸시 스위치 ON
        await tester.tap(find.byType(Switch).at(0));
        await tester.pumpAndSettle();

        // 모든 스위치 ON 확인
        switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
        expect(switches[0].value, isTrue);
        expect(switches[1].value, isTrue);
        expect(switches[2].value, isTrue);
        expect(switches[3].value, isTrue);
      }, () => client);
    });

    testWidgets('앱 전체 푸시 스위치 OFF → 리스크·호재·관심 종목 모두 OFF', (tester) async {
      final settingsAllOn = {
        'push': true,
        'risk_only': true,
        'positive_only': true,
        'interest_only': true,
        'night_push_prohibit': false,
        'dnd_start': '23:00:00',
        'dnd_finish': '07:00:00',
      };

      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/api/users/profile')) {
          return _jsonResponse(_mockProfile, 200);
        }
        if (path.contains('/api/users/settings')) {
          return _jsonResponse(settingsAllOn, 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 모든 스위치 ON 확인
        expect(
          tester.widgetList<Switch>(find.byType(Switch)).toList()[0].value,
          isTrue,
        );

        // 앱 전체 푸시 스위치 OFF
        await tester.tap(find.byType(Switch).at(0));
        await tester.pumpAndSettle();

        final switches =
            tester.widgetList<Switch>(find.byType(Switch)).toList();
        expect(switches[0].value, isFalse);
        expect(switches[1].value, isFalse);
        expect(switches[2].value, isFalse);
        expect(switches[3].value, isFalse);
      }, () => client);
    });

    testWidgets('야간 방해금지 모드 토글 성공 → "꺼짐"에서 시간 범위 텍스트로 변경', (tester) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/api/users/profile')) {
          return _jsonResponse(_mockProfile, 200);
        }
        if (path.contains('/api/users/settings')) {
          if (request.method == 'GET') return _jsonResponse(_mockSettings, 200);
          if (request.method == 'PATCH') {
            return _jsonResponse({
              ..._mockSettings,
              'night_push_prohibit': true,
            }, 200);
          }
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 초기: 꺼짐 상태 (스크롤 후 확인)
        await tester.ensureVisible(find.text('꺼짐'));
        await tester.pumpAndSettle();
        expect(find.text('꺼짐'), findsOneWidget);

        // 야간 방해금지 토글 탭
        await tester.tap(find.text('꺼짐'));
        await tester.pumpAndSettle();

        // 시간 범위 텍스트로 변경
        expect(find.text('꺼짐'), findsNothing);
        expect(find.textContaining('23:00'), findsOneWidget);
      }, () => client);
    });

    testWidgets('야간 방해금지 모드 토글 API 실패 → 원래 상태로 롤백 + 스낵바 표시',
        (tester) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/api/users/profile')) {
          return _jsonResponse(_mockProfile, 200);
        }
        if (path.contains('/api/users/settings')) {
          if (request.method == 'GET') return _jsonResponse(_mockSettings, 200);
          if (request.method == 'PATCH') return http.Response('error', 500);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('꺼짐'));
        await tester.pumpAndSettle();
        expect(find.text('꺼짐'), findsOneWidget);

        // 야간 방해금지 토글 탭
        await tester.tap(find.text('꺼짐'));
        await tester.pumpAndSettle();

        // 실패 후 롤백 → '꺼짐' 복원
        expect(find.text('꺼짐'), findsOneWidget);
        // 스낵바 표시
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('설정 변경에 실패'), findsOneWidget);
      }, () => client);
    });

    testWidgets('정보 초기화 다이얼로그 → 취소 클릭 → 스위치 상태 유지', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 리스크 알림 ON 확인
        expect(
          tester.widgetList<Switch>(find.byType(Switch)).toList()[1].value,
          isTrue,
        );

        // 정보 초기화 탭 (스크롤 후)
        await tester.ensureVisible(find.text('정보 초기화'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('정보 초기화'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('초기화 전 반드시 확인해주세요.'), findsOneWidget);

        // 취소 클릭
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();

        // 스위치 상태 유지
        expect(
          tester.widgetList<Switch>(find.byType(Switch)).toList()[1].value,
          isTrue,
        );
      }, _buildDefaultClient);
    });

    testWidgets('정보 초기화 다이얼로그 → 확인 클릭 → 알림 스위치 전체 OFF + 스낵바 표시',
        (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 정보 초기화 탭 (스크롤 후)
        await tester.ensureVisible(find.text('정보 초기화'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('정보 초기화'));
        await tester.pumpAndSettle();

        // 초기화 확인 클릭
        await tester.tap(find.text('초기화'));
        await tester.pumpAndSettle();

        // 모든 알림 스위치 OFF 확인
        final switches =
            tester.widgetList<Switch>(find.byType(Switch)).toList();
        expect(switches[0].value, isFalse); // 앱 전체 푸시
        expect(switches[1].value, isFalse); // 리스크 알림
        expect(switches[2].value, isFalse); // 호재 알림
        expect(switches[3].value, isFalse); // 관심 종목 알림

        // 완료 스낵바 표시
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('설정이 초기화되었습니다.'), findsOneWidget);
      }, _buildDefaultClient);
    });
  });
}
