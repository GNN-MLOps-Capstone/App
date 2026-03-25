// lib/screens/news_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'widgets/bottom_nav_bar.dart';
import '../models/news_models.dart';
import '../services/news_api_service.dart';
import '../services/user_api_service.dart';
import '../config/api_config.dart';
import 'news_detail_page.dart';

const bool _enableDummyNewsFallback = bool.fromEnvironment(
  'ENABLE_DUMMY_NEWS_FALLBACK',
  defaultValue: false,
);

// ===================== 더미데이터 (총 40개 - 페이지당 20개씩 2페이지) =====================

final List<Map<String, dynamic>> _dummyPage1 = [
  {'news_id': 231353, 'title': '[경제쏙] 자사주 소각, \'트럼프\' 널뛰기 증시에 \'단비\'', 'summary': '3차 상법개정안 시행으로 삼성전자, SK 등 대기업들의 자사주 소각 계획 발표와 주가 상승, 중소·중견 기업의 자사주 소각 관련 내용.', 'pub_date': '2026-03-12T06:34:00', 'path': 'A1', 'stock_name': '삼성전자', 'stock_change': '+3.2%', 'stock_up': true},
  {'news_id': 231321, 'title': '기술은 잘 나가는데 내 자리는요? 코엑스에 몰려온 애타는 청춘들', 'summary': '배터리 산업의 채용 시장이 전기차 캐즘과 AI 기술 발전으로 인해 어려움을 겪고 있으며, ESS 분야로의 전환과 기업별 목표 설정이 중요해지고 있다.', 'pub_date': '2026-03-12T07:08:00', 'path': 'A1', 'stock_name': 'SK하이닉스', 'stock_change': '+7.2%', 'stock_up': true},
  {'news_id': 231226, 'title': '이경실 "깡통 주식만 3억 넘어…7만원 본전에 판 삼성전자 꼴도 보기 싫어"', 'summary': '개그우먼 이경실이 과거 삼성전자 주식 투자 실패 경험과 부동산 투자 실패담을 언급하며 재테크 관련 이야기를 나눔.', 'pub_date': '2026-03-12T07:47:00', 'path': 'A2', 'stock_name': '삼성전자', 'stock_change': '-1.2%', 'stock_up': false},
  {'news_id': 231270, 'title': '"국내 AI 소비자들, 주변엔 챗GPT보다 제미나이 추천"', 'summary': '컨슈머인사이트 조사에서 챗GPT는 이용률 1위이나, 추천의향은 제미나이가 더 높게 나타나 AI 서비스 시장 경쟁 구도를 보여줌.', 'pub_date': '2026-03-12T07:30:00', 'path': 'A2', 'stock_name': '카카오', 'stock_change': '-0.8%', 'stock_up': false},
  {'news_id': 227736, 'title': '바이오시밀러 SC면 다 잘되는 줄 알지만... 처방 패턴 바뀌면 \'헛일\'', 'summary': '바이오시밀러 시장 경쟁에서 SC 제형의 중요성을 분석하며, 셀트리온, 삼성바이오에피스 등 기업들의 사례를 통해 시장 접근 전략을 제시.', 'pub_date': '2026-03-10T21:12:00', 'path': 'A1', 'stock_name': '셀트리온', 'stock_change': '+2.1%', 'stock_up': true},
  {'news_id': 215033, 'title': '\'군사기지 사용 거절\' 스페인에 보복 나선 트럼프', 'summary': '트럼프 대통령이 스페인의 기지 사용 거부에 대한 보복으로 무역 단절을 선언하고, 이란과의 군사적 긴장 고조에 대한 입장을 밝혔다.', 'pub_date': '2026-03-03T21:19:00', 'path': 'A2', 'stock_name': '한화에어로', 'stock_change': '+5.3%', 'stock_up': true},
  {'news_id': 214800, 'title': '삼성전자, HBM3E 8단 3분기 본격 양산 엔비디아 공급 가능성', 'summary': '삼성전자가 AI 메모리인 HBM3E 8단 제품을 3분기 내 본격 양산하고, 12단 제품도 하반기에 공급할 예정입니다.', 'pub_date': '2026-03-12T14:00:00', 'path': 'A1', 'stock_name': '삼성전자', 'stock_change': '+3.2%', 'stock_up': true},
  {'news_id': 214750, 'title': 'SK하이닉스, 2분기 HBM 공급 확대… 영업이익 사상 최대 전망', 'summary': 'SK하이닉스가 2분기 HBM 공급을 대폭 확대하며 영업이익 사상 최대치를 기록할 것으로 시장이 전망하고 있다.', 'pub_date': '2026-03-11T09:00:00', 'path': 'A1', 'stock_name': 'SK하이닉스', 'stock_change': '+7.2%', 'stock_up': true},
  {'news_id': 214700, 'title': '현대차, 전기차 신모델 출시… 테슬라와 정면 승부', 'summary': '현대자동차가 새로운 전기차 모델을 출시하며 글로벌 시장에서 테슬라와 본격적인 경쟁에 나선다.', 'pub_date': '2026-03-10T10:30:00', 'path': 'A1', 'stock_name': '현대차', 'stock_change': '+2.8%', 'stock_up': true},
  {'news_id': 214650, 'title': 'POSCO홀딩스, 리튬 생산 본격화… 2차전지 소재 공급 확대', 'summary': 'POSCO홀딩스가 아르헨티나 리튬 염호에서 본격적인 리튬 생산을 시작하며 2차전지 소재 시장 공급 확대에 나섰다.', 'pub_date': '2026-03-09T11:00:00', 'path': 'A1', 'stock_name': 'POSCO홀딩스', 'stock_change': '+4.1%', 'stock_up': true},
  {'news_id': 214600, 'title': '카카오뱅크, 대출 금리 인하… 시중은행과 경쟁 심화', 'summary': '카카오뱅크가 주요 대출 금리를 인하하며 시중은행과의 경쟁이 더욱 치열해질 전망이다.', 'pub_date': '2026-03-08T09:30:00', 'path': 'A2', 'stock_name': '카카오뱅크', 'stock_change': '-0.5%', 'stock_up': false},
  {'news_id': 214550, 'title': 'LG에너지솔루션, GM과 배터리 합작 법인 추가 투자 결정', 'summary': 'LG에너지솔루션이 GM과의 배터리 합작 법인에 추가 투자를 결정하며 북미 전기차 배터리 시장 공략을 강화한다.', 'pub_date': '2026-03-07T13:00:00', 'path': 'A1', 'stock_name': 'LG에너지솔루션', 'stock_change': '+3.5%', 'stock_up': true},
  {'news_id': 214500, 'title': '네이버, 생성형 AI 서비스 월간 활성 사용자 1000만 돌파', 'summary': '네이버의 생성형 AI 서비스 클로바X가 출시 6개월 만에 월간 활성 사용자 1000만 명을 돌파했다.', 'pub_date': '2026-03-06T10:00:00', 'path': 'A1', 'stock_name': '네이버', 'stock_change': '+1.9%', 'stock_up': true},
  {'news_id': 214450, 'title': '두산에너빌리티, 소형모듈원전 수주 기대감에 주가 급등', 'summary': '두산에너빌리티가 미국 SMR 프로젝트 수주 기대감으로 주가가 크게 상승하며 시장의 주목을 받고 있다.', 'pub_date': '2026-03-05T14:30:00', 'path': 'A1', 'stock_name': '두산에너빌리티', 'stock_change': '+8.2%', 'stock_up': true},
  {'news_id': 214400, 'title': '삼성바이오로직스, 글로벌 제약사 위탁생산 계약 체결', 'summary': '삼성바이오로직스가 글로벌 주요 제약사와 대규모 바이오의약품 위탁생산 계약을 체결했다고 공시했다.', 'pub_date': '2026-03-04T09:00:00', 'path': 'A1', 'stock_name': '삼성바이오로직스', 'stock_change': '+2.3%', 'stock_up': true},
  {'news_id': 214350, 'title': '한국전력, 전기요금 추가 인상 검토… 적자 해소 총력', 'summary': '한국전력이 누적 적자 해소를 위해 추가적인 전기요금 인상을 검토 중인 것으로 알려졌다.', 'pub_date': '2026-03-03T11:30:00', 'path': 'A2', 'stock_name': '한국전력', 'stock_change': '-1.8%', 'stock_up': false},
  {'news_id': 214300, 'title': '기아차, 픽업트럭 타스만 글로벌 판매 호조', 'summary': '기아자동차의 픽업트럭 타스만이 호주·중동 시장에서 판매 호조를 보이며 글로벌 픽업트럭 시장 공략에 청신호가 켜졌다.', 'pub_date': '2026-03-02T15:00:00', 'path': 'A1', 'stock_name': '기아', 'stock_change': '+1.5%', 'stock_up': true},
  {'news_id': 214250, 'title': 'KB금융, 자사주 매입 소각 확대… 주주환원 강화', 'summary': 'KB금융그룹이 자사주 매입 및 소각 규모를 확대하며 주주환원 정책을 한층 강화하기로 결정했다.', 'pub_date': '2026-03-01T10:00:00', 'path': 'A1', 'stock_name': 'KB금융', 'stock_change': '+2.0%', 'stock_up': true},
  {'news_id': 214200, 'title': '크래프톤, 신작 게임 글로벌 출시… 배그 흥행 이을까', 'summary': '크래프톤이 새로운 배틀로얄 장르 게임을 글로벌 시장에 출시하며 배틀그라운드의 흥행을 이을 수 있을지 주목된다.', 'pub_date': '2026-02-28T13:00:00', 'path': 'A1', 'stock_name': '크래프톤', 'stock_change': '+5.7%', 'stock_up': true},
  {'news_id': 214150, 'title': '코스피, 외국인 순매수에 2600선 회복… 반도체주 강세', 'summary': '코스피 지수가 외국인의 대규모 순매수에 힘입어 2600선을 회복하며 반도체 관련 주식들이 강세를 보였다.', 'pub_date': '2026-02-27T16:00:00', 'path': 'A1', 'stock_name': '삼성전자', 'stock_change': '+1.8%', 'stock_up': true},
];

final List<Map<String, dynamic>> _dummyPage2 = [
  {'news_id': 214100, 'title': '포스코퓨처엠, 양극재 생산 능력 대폭 확대 계획 발표', 'summary': '포스코퓨처엠이 2차전지 핵심 소재인 양극재 생산 능력을 대폭 확대하는 계획을 발표하며 배터리 소재 시장 주도권 확보에 나섰다.', 'pub_date': '2026-02-26T10:30:00', 'path': 'A1', 'stock_name': '포스코퓨처엠', 'stock_change': '+3.9%', 'stock_up': true},
  {'news_id': 214050, 'title': '하이브, 새 아티스트 데뷔로 주가 상승 기대', 'summary': '하이브가 새로운 아이돌 그룹 데뷔를 앞두고 글로벌 팬덤 형성에 주력하며 엔터테인먼트 시장 공략을 강화하고 있다.', 'pub_date': '2026-02-25T09:00:00', 'path': 'A1', 'stock_name': '하이브', 'stock_change': '+4.2%', 'stock_up': true},
  {'news_id': 214000, 'title': '롯데케미칼, 석유화학 업황 부진에 실적 악화 우려', 'summary': '롯데케미칼이 글로벌 석유화학 업황 부진으로 인해 올해 실적이 크게 악화될 것이라는 우려가 시장에서 제기되고 있다.', 'pub_date': '2026-02-24T14:00:00', 'path': 'A2', 'stock_name': '롯데케미칼', 'stock_change': '-2.3%', 'stock_up': false},
  {'news_id': 213950, 'title': '카카오게임즈, 신작 RPG 사전예약 100만 돌파', 'summary': '카카오게임즈의 신작 모바일 RPG가 출시 전 사전예약자 100만 명을 돌파하며 흥행 기대감을 높이고 있다.', 'pub_date': '2026-02-23T11:00:00', 'path': 'A1', 'stock_name': '카카오게임즈', 'stock_change': '+6.1%', 'stock_up': true},
  {'news_id': 213900, 'title': '현대건설, 중동 대형 건설 프로젝트 수주 성공', 'summary': '현대건설이 사우디아라비아 네옴시티 관련 대형 건설 프로젝트를 수주하며 해외 건설 시장에서의 경쟁력을 과시했다.', 'pub_date': '2026-02-22T10:00:00', 'path': 'A1', 'stock_name': '현대건설', 'stock_change': '+3.4%', 'stock_up': true},
  {'news_id': 213850, 'title': '삼성SDI, 전고체 배터리 2027년 양산 목표 재확인', 'summary': '삼성SDI가 차세대 배터리로 주목받는 전고체 배터리의 2027년 양산 목표를 재확인하며 기술 개발에 박차를 가하고 있다.', 'pub_date': '2026-02-21T13:30:00', 'path': 'A1', 'stock_name': '삼성SDI', 'stock_change': '+2.7%', 'stock_up': true},
  {'news_id': 213800, 'title': 'LG전자, 올레드 TV 글로벌 점유율 70% 돌파', 'summary': 'LG전자의 올레드 TV가 글로벌 시장에서 70% 이상의 점유율을 기록하며 프리미엄 TV 시장을 압도하고 있다.', 'pub_date': '2026-02-20T09:00:00', 'path': 'A1', 'stock_name': 'LG전자', 'stock_change': '+1.6%', 'stock_up': true},
  {'news_id': 213750, 'title': '셀트리온, 미국 FDA 바이오시밀러 허가 획득', 'summary': '셀트리온이 자사 바이오시밀러 제품에 대해 미국 FDA로부터 판매 허가를 획득하며 미국 시장 진출의 발판을 마련했다.', 'pub_date': '2026-02-19T15:00:00', 'path': 'A1', 'stock_name': '셀트리온', 'stock_change': '+5.8%', 'stock_up': true},
  {'news_id': 213700, 'title': '코스닥, 바이오주 약세에 700선 하회… 투자심리 위축', 'summary': '코스닥 지수가 바이오 관련 주식들의 약세로 700선을 하회하며 투자 심리가 위축되고 있다.', 'pub_date': '2026-02-18T16:30:00', 'path': 'A2', 'stock_name': '셀트리온', 'stock_change': '-1.4%', 'stock_up': false},
  {'news_id': 213650, 'title': 'KT, AI 기반 네트워크 자동화 솔루션 출시', 'summary': 'KT가 인공지능 기반의 네트워크 자동화 솔루션을 출시하며 B2B 시장에서의 경쟁력 강화에 나섰다.', 'pub_date': '2026-02-17T10:00:00', 'path': 'A1', 'stock_name': 'KT', 'stock_change': '+1.2%', 'stock_up': true},
  {'news_id': 213600, 'title': '한화오션, 미 해군 함정 MRO 사업 수주 추진', 'summary': '한화오션이 미국 해군 함정의 유지보수 사업 수주를 추진하며 방산 분야에서의 글로벌 영향력 확대에 나서고 있다.', 'pub_date': '2026-02-16T11:30:00', 'path': 'A1', 'stock_name': '한화오션', 'stock_change': '+7.3%', 'stock_up': true},
  {'news_id': 213550, 'title': '에코프로비엠, 하이니켈 양극재 유럽 공급 계약 체결', 'summary': '에코프로비엠이 유럽 주요 배터리 제조사와 하이니켈 양극재 장기 공급 계약을 체결하며 유럽 시장 공략을 본격화했다.', 'pub_date': '2026-02-15T09:30:00', 'path': 'A1', 'stock_name': '에코프로비엠', 'stock_change': '+4.5%', 'stock_up': true},
  {'news_id': 213500, 'title': '신한금융, 베트남 금융 시장 공략 강화', 'summary': '신한금융그룹이 베트남 현지 금융 서비스를 확대하며 동남아시아 금융 시장에서의 입지 강화에 나서고 있다.', 'pub_date': '2026-02-14T14:00:00', 'path': 'A1', 'stock_name': '신한금융', 'stock_change': '+1.7%', 'stock_up': true},
  {'news_id': 213450, 'title': '넷마블, 해외 게임 인수로 글로벌 IP 강화', 'summary': '넷마블이 해외 유명 게임사 인수를 통해 글로벌 게임 IP 포트폴리오를 강화하며 국제 경쟁력 제고에 나서고 있다.', 'pub_date': '2026-02-13T10:00:00', 'path': 'A2', 'stock_name': '넷마블', 'stock_change': '-0.9%', 'stock_up': false},
  {'news_id': 213400, 'title': '대한항공, 아시아나 합병 완료… 메가캐리어 출범', 'summary': '대한항공이 아시아나항공과의 합병을 완료하며 국내 최초의 메가캐리어가 출범했다. 글로벌 항공 시장에서의 경쟁력이 크게 강화될 전망이다.', 'pub_date': '2026-02-12T09:00:00', 'path': 'A1', 'stock_name': '대한항공', 'stock_change': '+3.1%', 'stock_up': true},
  {'news_id': 213350, 'title': '고려아연, 경영권 분쟁 일단락… 주가 안정세', 'summary': '고려아연의 경영권 분쟁이 일단락되며 주가가 안정세를 찾아가고 있다. 향후 사업 방향에 대한 시장의 관심이 집중되고 있다.', 'pub_date': '2026-02-11T15:30:00', 'path': 'A2', 'stock_name': '고려아연', 'stock_change': '-0.6%', 'stock_up': false},
  {'news_id': 213300, 'title': 'HD현대중공업, 친환경 LNG선 대규모 수주 성공', 'summary': 'HD현대중공업이 글로벌 주요 선사로부터 친환경 LNG 운반선 대규모 수주에 성공하며 조선 업황 회복에 청신호가 켜졌다.', 'pub_date': '2026-02-10T10:00:00', 'path': 'A1', 'stock_name': 'HD현대중공업', 'stock_change': '+4.8%', 'stock_up': true},
  {'news_id': 213250, 'title': '카카오, 계열사 구조조정 가속화… 핵심 사업에 집중', 'summary': '카카오그룹이 비핵심 계열사에 대한 구조조정을 가속화하며 AI와 플랫폼 핵심 사업에 역량을 집중하기로 전략 방향을 변경했다.', 'pub_date': '2026-02-09T11:00:00', 'path': 'A2', 'stock_name': '카카오', 'stock_change': '-1.3%', 'stock_up': false},
  {'news_id': 213200, 'title': '메리츠금융, 역대 최대 실적 경신… 주주환원 확대', 'summary': '메리츠금융그룹이 역대 최대 실적을 경신하며 배당과 자사주 매입 등 주주환원 정책을 대폭 확대하기로 결정했다.', 'pub_date': '2026-02-08T09:30:00', 'path': 'A1', 'stock_name': '메리츠금융', 'stock_change': '+3.2%', 'stock_up': true},
  {'news_id': 213150, 'title': '엔씨소프트, 신작 TL 글로벌 흥행으로 실적 반전 기대', 'summary': '엔씨소프트의 신작 게임 TL이 글로벌 시장에서 흥행에 성공하며 오랜 실적 부진을 벗어날 수 있을지 시장의 기대가 높아지고 있다.', 'pub_date': '2026-02-07T14:00:00', 'path': 'A1', 'stock_name': '엔씨소프트', 'stock_change': '+6.4%', 'stock_up': true},
  {'news_id': 213100, 'title': '삼성물산, 패션·리조트 부문 실적 개선으로 주가 상승', 'summary': '삼성물산의 패션과 리조트 부문 실적이 크게 개선되며 주가가 상승세를 이어가고 있다.', 'pub_date': '2026-02-06T10:30:00', 'path': 'A1', 'stock_name': '삼성물산', 'stock_change': '+2.1%', 'stock_up': true},
];

// ===================== 이벤트 로거 =====================

class _EventLogger {
  static final _uuid = Uuid();
  static const _storage = FlutterSecureStorage();
  static String get _baseUrl => ApiConfig.baseUrl;
  static const _endpoint = '/api/interactions/events';

  static Future<void> post(List<Map<String, dynamic>> events) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        Uri.parse('$_baseUrl$_endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'events': events}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[EventLogger] 이벤트 전송 실패(status=${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[EventLogger] 이벤트 전송 실패: $e');
    }
  }

  static String newId() => _uuid.v4();
  static String nowIso() => DateTime.now().toUtc().toIso8601String();
}

// ===================== 메인 화면 =====================

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final String _appSessionId = _EventLogger.newId();
  final String _screenSessionId = _EventLogger.newId();
  final ScrollController _scrollController = ScrollController();
  final List<NewsRecommendationItem> _items = [];

  late String _requestId;
  String? _nextCursor;
  String? _openContentSessionId;
  int? _userId;
  int _page = 1;
  int _dummyPage = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _usingDummy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestId = _EventLogger.newId();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sendScreenLeave();
    super.dispose();
  }

  Future<void> _postEvents(List<Map<String, dynamic>> events) async {
    final userId = _userId;
    if (userId == null || events.isEmpty) return;
    final payload = events
        .map((event) => <String, dynamic>{'user_id': userId, ...event})
        .toList();
    await _EventLogger.post(payload);
  }

  Future<void> _init() async {
    try {
      final profile = await UserApiService.getProfile();
      _userId = profile.id > 0 ? profile.id : null;
    } catch (_) {
      _userId = null;
    }

    await _postEvents([
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'screen_view',
        'app_session_id': _appSessionId,
        'screen_session_id': _screenSessionId,
        'request_id': _requestId,
      },
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'recommendation_request',
        'app_session_id': _appSessionId,
        'screen_session_id': _screenSessionId,
        'request_id': _requestId,
        'page': 1,
        'event_ts_client': _EventLogger.nowIso(),
      },
    ]);

    await _loadRecommendations(
      requestId: _requestId,
      allowDummyFallback: _enableDummyNewsFallback,
    );
  }

  Future<void> _loadRecommendations({
    required String requestId,
    bool isMore = false,
    String? cursor,
    bool allowDummyFallback = false,
  }) async {
    if (!mounted) return;
    setState(() {
      if (isMore) {
        _loadingMore = true;
      } else {
        _loading = true;
        _errorMessage = null;
      }
    });

    try {
      final response = await NewsApiService.getRecommendations(
        cursor: cursor,
        requestId: requestId,
        screenSessionId: _screenSessionId,
        appSessionId: _appSessionId,
      );

      if (!mounted) return;
      setState(() {
        _usingDummy = false;
        _requestId = response.requestId;
        _page = response.page;
        _nextCursor = response.nextCursor;
        _hasMore = response.nextCursor != null;
        _loading = false;
        _loadingMore = false;
        _errorMessage = null;
        if (isMore) {
          _items.addAll(response.items);
        } else {
          _items
            ..clear()
            ..addAll(response.items);
        }
      });

      await _postEvents([
        {
          'event_id': _EventLogger.newId(),
          'event_type': 'recommendation_response',
          'app_session_id': _appSessionId,
          'screen_session_id': _screenSessionId,
          'request_id': requestId,
          'event_ts_client': _EventLogger.nowIso(),
          'page': response.page,
        },
      ]);
    } catch (e) {
      debugPrint(
        '[NewsScreen] 추천 뉴스 로드 실패(requestId=$requestId, isMore=$isMore): $e',
      );
      if (allowDummyFallback) {
        await _loadDummy(isMore: isMore);
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _errorMessage = '추천 뉴스를 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _loadDummy({bool isMore = false}) async {
    if (!mounted) return;
    if (!isMore) {
      _dummyPage = 1;
    } else if (_dummyPage < 2) {
      _dummyPage += 1;
    }

    // 페이지에 맞는 더미데이터 선택
    final pageData = _dummyPage <= 1 ? _dummyPage1 : _dummyPage2;
    final fallbackItems = pageData
        .map(
          (item) => NewsRecommendationItem.fromJson({
            ...item,
            'is_placeholder': true,
          }),
        )
        .toList();

    setState(() {
      _usingDummy = true;
      _page = _dummyPage;
      _nextCursor = null;
      _hasMore = _dummyPage < 2;
      _loading = false;
      _loadingMore = false;
      _errorMessage = null;
      if (isMore) {
        _items.addAll(fallbackItems);
      } else {
        _items
          ..clear()
          ..addAll(fallbackItems);
      }
    });
  }

  // ── 더보기 버튼 클릭 ──
  Future<void> _onLoadMore() async {
    if (_loadingMore || !_hasMore) return;

    if (_usingDummy) {
      setState(() => _loadingMore = true);
      await _loadDummy(isMore: true);
      return;
    }

    if (_nextCursor == null) return;

    final maxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final scrollDepth = maxExtent > 0 && _scrollController.hasClients
        ? (_scrollController.position.pixels / maxExtent * 100).clamp(0, 100)
        : 100.0;
    final nextRequestId = _EventLogger.newId();

    await _postEvents([
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'scroll_depth',
        'app_session_id': _appSessionId,
        'screen_session_id': _screenSessionId,
        'request_id': nextRequestId,
        'event_ts_client': _EventLogger.nowIso(),
        'page': _page + 1,
        'scroll_depth': scrollDepth,
      },
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'recommendation_request',
        'app_session_id': _appSessionId,
        'screen_session_id': _screenSessionId,
        'request_id': nextRequestId,
        'event_ts_client': _EventLogger.nowIso(),
        'page': _page + 1,
      },
    ]);

    await _loadRecommendations(
      requestId: nextRequestId,
      isMore: true,
      cursor: _nextCursor,
      allowDummyFallback: _enableDummyNewsFallback,
    );
  }

  Future<void> _onNewsTap(NewsRecommendationItem item, int index) async {
    final contentSessionId = _EventLogger.newId();
    _openContentSessionId = contentSessionId;

    await _postEvents([
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'content_open',
        'app_session_id': _appSessionId,
        'screen_session_id': _screenSessionId,
        'content_session_id': contentSessionId,
        'request_id': _requestId,
        'event_ts_client': _EventLogger.nowIso(),
        'news_id': item.newsId,
        'position': index + 1,
        'page': _page,
      },
    ]);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailPage(
          newsId: item.newsId,
          initialItem: item,
        ),
      ),
    );
    await _onNewsLeave();
  }

  Future<void> _onNewsLeave() async {
    if (_openContentSessionId == null) return;
    await _postEvents([
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'content_leave',
        'app_session_id': _appSessionId,
        'content_session_id': _openContentSessionId,
        'event_ts_client': _EventLogger.nowIso(),
      },
    ]);
    _openContentSessionId = null;
  }

  Future<void> _sendScreenLeave() async {
    await _postEvents([
      {
        'event_id': _EventLogger.newId(),
        'event_type': 'screen_leave',
        'app_session_id': _appSessionId,
        'screen_session_id': _screenSessionId,
        'event_ts_client': _EventLogger.nowIso(),
      },
    ]);
  }

  void _onBottomTap(int index) {
    if (index == 2) return;
    final routeMap = {0: '/home', 1: '/watchlist', 3: '/stock'};
    final route = routeMap[index];
    if (route == null) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 2,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('회원님을 위한 추천 뉴스',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 15, height: 15,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: Color(0xFF0EC272), shape: BoxShape.circle),
                          child: const Text('2',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.settings, size: 26, color: Colors.black),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 뉴스 리스트 ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF606060),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => _loadRecommendations(requestId: _requestId),
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? const Center(child: Text('추천 뉴스가 없습니다.'))
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _items.length + 1,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index == _items.length) {
                                  if (_loadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  if (_hasMore) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: _onLoadMore,
                                          child: const Text(
                                            '더보기',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF83848B),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox(height: 12);
                                }

                                return GestureDetector(
                                  onTap: () => _onNewsTap(_items[index], index),
                                  child: _NewsCard(item: _items[index]),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== 뉴스 카드 =====================

class _NewsCard extends StatelessWidget {
  final NewsRecommendationItem item;

  const _NewsCard({required this.item});

  bool get _isUp => item.stockUp == true;

  String _relativeTime() {
    final pubDate = item.pubDate;
    if (pubDate == null) return '';
    final diff = DateTime.now().difference(pubDate);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _relativeTime();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 169,
            height: 93,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.asset(
                  'assets/images/green_background.svg',
                  fit: BoxFit.none,
                ),
                Opacity(
                  opacity: 0.5,
                  child: SvgPicture.asset(
                    'assets/images/shadow.svg',
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.stockUp != null)
                        SvgPicture.asset(
                          _isUp
                              ? 'assets/images/up_arrow.svg'
                              : 'assets/images/down_arrow.svg',
                          width: 8,
                          height: 8,
                        )
                      else
                        const SizedBox(width: 8, height: 8),
                      const Spacer(),
                      Text(
                        item.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF606060),
                  ),
                ),
              const SizedBox(height: 3),
              if (item.stockName != null && item.stockChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E3E3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${item.stockName}  ',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: item.stockChange,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: item.stockUp == false
                                ? const Color(0xFF1E3CD6)
                                : const Color(0xFFE63E3E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
