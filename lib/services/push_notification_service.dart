import 'package:flutter/foundation.dart';
import 'onesignal_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // ⚠️ 보안 경고: 클라이언트에서 직접 OneSignal REST API를 호출하는 것은 심각한 보안 위험입니다!
  // 이 코드는 즉시 서버사이드 API로 마이그레이션해야 합니다.
  // 현재는 테스트 목적으로 비활성화했습니다.

  // 푸시 알림 발송 (현재 비활성화된 상태)
  Future<bool> sendPushNotification({
    required String title,
    required String message,
    String? targetUserId,
    List<String>? targetUserIds,
    Map<String, String>? data,
    List<String>? segments,
  }) async {
    if (kDebugMode) {
      print('⚠️ 보안 경고: 클라이언트 푸시 발송이 비활성화되었습니다.');
      print('서버사이드 API 구축 후 재활성화해야 합니다.');
      print('타겟 정보: $targetUserId, 제목: $title, 메시지: $message');
    }

    // 보안을 위해 클라이언트에서는 푸시 발송을 하지 않음
    return false;
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