import 'package:flutter/material.dart';
import '../services/onesignal_service.dart';
import '../services/push_notification_service.dart';

class PushTestScreen extends StatefulWidget {
  const PushTestScreen({Key? key}) : super(key: key);

  @override
  State<PushTestScreen> createState() => _PushTestScreenState();
}

class _PushTestScreenState extends State<PushTestScreen> {
  final OneSignalService _oneSignalService = OneSignalService();
  final PushNotificationService _pushService = PushNotificationService();
  String? _pushToken;
  bool _isSubscribed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAndCheckStatus();
  }

  Future<void> _initializeAndCheckStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    // OneSignal 초기화
    await _oneSignalService.initializeOneSignal();

    // 상태 확인
    await _checkNotificationStatus();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkNotificationStatus() async {
    final token = await _oneSignalService.getPushToken();
    final isSubscribed = await _oneSignalService.isNotificationSubscribed();

    if (mounted) {
      setState(() {
        _pushToken = token;
        _isSubscribed = isSubscribed;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    final success = await _pushService.sendPushNotification(
      title: '테스트 알림',
      message: '이것은 테스트 푸시 알림입니다!',
      data: {
        'type': 'test',
        'screen': 'push_test',
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '알림 발송 성공!' : '알림 발송 실패'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _sendStockPriceAlert() async {
    final success = await _pushService.sendStockPriceAlert(
      stockName: '삼성전자',
      stockCode: '005930',
      currentPrice: 85000,
      targetPrice: 86000,
      alertType: 'upper',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '주식 가격 알림 발송 성공!' : '알림 발송 실패'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _sendTradeNotification() async {
    final success = await _pushService.sendTradeNotification(
      stockName: 'LG에너지솔루션',
      stockCode: '373220',
      tradeType: 'buy',
      quantity: 10,
      price: 450000,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '거래 체결 알림 발송 성공!' : '알림 발송 실패'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _sendNewsNotification() async {
    final success = await _pushService.sendStockNewsNotification(
      stockName: 'SK하이닉스',
      stockCode: '000660',
      newsTitle: 'SK하이닉스, 반도체 시장 확대로 실적 개선 기대',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '뉴스 알림 발송 성공!' : '알림 발송 실패'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshStatus() async {
    await _checkNotificationStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상태가 새로고침되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('푸시 알림 테스트'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상태 정보
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '푸시 알림 상태',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _isSubscribed ? Icons.check_circle : Icons.error,
                                color: _isSubscribed ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '구독 상태: ${_isSubscribed ? "활성화" : "비활성화"}',
                                style: TextStyle(
                                  color: _isSubscribed ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '푸시 토큰: ${_pushToken ?? "없음"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _refreshStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('상태 새로고침'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 테스트 알림
                  const Text(
                    '테스트 알림',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTestButton(
                    '기본 테스트 알림',
                    Icons.notifications,
                    Colors.blue,
                    _sendTestNotification,
                  ),
                  _buildTestButton(
                    '주식 가격 알림',
                    Icons.trending_up,
                    Colors.green,
                    _sendStockPriceAlert,
                  ),
                  _buildTestButton(
                    '거래 체결 알림',
                    Icons.candlestick_chart,
                    Colors.orange,
                    _sendTradeNotification,
                  ),
                  _buildTestButton(
                    '뉴스 알림',
                    Icons.article,
                    Colors.purple,
                    _sendNewsNotification,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTestButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}