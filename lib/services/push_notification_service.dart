import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'onesignal_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // OneSignal REST API를 사용한 푸시 알림 발송 (팀 내부 프로젝트용)
  Future<bool> sendPushNotification({
    required String title,
    required String message,
    String? targetUserId,
    List<String>? targetUserIds,
    Map<String, String>? data,
    List<String>? segments,
  }) async {
    try {
      String? appId = dotenv.env['ONESIGNAL_APP_ID'];
      String? apiKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

      if (appId == null || apiKey == null ||
          appId.isEmpty || apiKey.isEmpty) {
        if (kDebugMode) {
          print('OneSignal App ID 또는 API Key가 설정되지 않았습니다.');
        }
        return false;
      }

      // OneSignal API 페이로드 구성
      Map<String, dynamic> payload = {
        'app_id': appId,
        'contents': {'en': message, 'ko': message},
        'headings': {'en': title, 'ko': title},
      };

      // 타겟 설정
      if (targetUserId != null) {
        payload['include_player_ids'] = [targetUserId];
      } else if (targetUserIds != null && targetUserIds.isNotEmpty) {
        payload['include_player_ids'] = targetUserIds;
      } else {
        // 자신의 토큰으로 발송
        String? ownToken = await OneSignalService().getPushToken();
        if (ownToken != null && ownToken.isNotEmpty) {
          payload['include_player_ids'] = [ownToken];
        } else {
          // 팀 내부 프로젝트: 구독된 사용자에게 발송
          payload['included_segments'] = ['Subscribed Users'];
        }
      }

      // 추가 데이터 설정
      if (data != null && data.isNotEmpty) {
        payload['data'] = data;
      }

      // API 호출
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $apiKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ 푸시 알림 발송 성공: $title');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ 푸시 알림 발송 실패: ${response.statusCode}');
          print('응답: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 푸시 알림 발송 오류: $e');
      }
      return false;
    }
  }

  // 주식 가격 알림
  Future<bool> sendStockPriceAlert({
    required String stockName,
    required String stockCode,
    required int currentPrice,
    required int targetPrice,
    required String alertType, // 'upper' or 'lower'
    String? targetUserId,
  }) async {
    String message;
    if (alertType == 'upper') {
      message = '$stockName($stockCode)이 목표가 $targetPrice원에 도달했습니다. 현재가: $currentPrice원';
    } else {
      message = '$stockName($stockCode)이 목표가 $targetPrice원 이하로 떨어졌습니다. 현재가: $currentPrice원';
    }

    return await sendPushNotification(
      title: '주식 가격 알림',
      message: message,
      targetUserId: targetUserId,
      data: {
        'type': 'stock_price',
        'stock_code': stockCode,
        'stock_name': stockName,
        'current_price': currentPrice.toString(),
        'target_price': targetPrice.toString(),
        'alert_type': alertType,
      },
    );
  }

  // 거래 체결 알림
  Future<bool> sendTradeNotification({
    required String stockName,
    required String stockCode,
    required String tradeType, // 'buy' or 'sell'
    required int quantity,
    required int price,
    String? targetUserId,
  }) async {
    String typeText = tradeType == 'buy' ? '매수' : '매도';
    String message = '$stockName($stockCode) $typeText ${quantity}주가 $price원에 체결되었습니다.';

    return await sendPushNotification(
      title: '거래 체결 알림',
      message: message,
      targetUserId: targetUserId,
      data: {
        'type': 'trade_complete',
        'stock_code': stockCode,
        'stock_name': stockName,
        'trade_type': tradeType,
        'quantity': quantity.toString(),
        'price': price.toString(),
      },
    );
  }

  // 관심 종목 알림
  Future<bool> sendFavoriteStockAlert({
    required String stockName,
    required String stockCode,
    required String alertMessage,
    String? targetUserId,
  }) async {
    return await sendPushNotification(
      title: '관심 종목 알림',
      message: '$stockName($stockCode): $alertMessage',
      targetUserId: targetUserId,
      data: {
        'type': 'favorite_stock',
        'stock_code': stockCode,
        'stock_name': stockName,
        'alert_message': alertMessage,
      },
    );
  }

  // 뉴스 알림
  Future<bool> sendStockNewsNotification({
    required String stockName,
    required String stockCode,
    required String newsTitle,
    String? targetUserId,
  }) async {
    return await sendPushNotification(
      title: '$stockName 관련 뉴스',
      message: newsTitle.length > 50 ? '${newsTitle.substring(0, 50)}...' : newsTitle,
      targetUserId: targetUserId,
      data: {
        'type': 'stock_news',
        'stock_code': stockCode,
        'stock_name': stockName,
        'news_title': newsTitle,
      },
    );
  }
}