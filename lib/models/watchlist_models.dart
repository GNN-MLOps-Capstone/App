class WatchlistStock {
  final String code;
  final String name;
  final String weather; // "SUNNY" | "CLOUDY" | "RAINY"
  final int price;
  final double changeRate;
  final String keyword;
  final String aiSummary;
  final double issueIndex; // 추가
  final int volume;        // 추가

  WatchlistStock({
    required this.code,
    required this.name,
    required this.weather,
    required this.price,
    required this.changeRate,
    required this.keyword,
    required this.aiSummary,
    this.issueIndex = 0.0, // 기본값 설정 (기존 코드 안 깨짐)
    this.volume = 0,       // 기본값 설정 (기존 코드 안 깨짐)
  });

  factory WatchlistStock.fromJson(Map<String, dynamic> json) {
    return WatchlistStock(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      weather: json['weather'] as String? ?? 'CLOUDY',
      price: (json['price'] as num?)?.toInt() ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0.0,
      keyword: json['keyword'] as String? ?? '',
      aiSummary: json['aiSummary'] as String? ?? '',
      issueIndex: (json['issueIndex'] as num?)?.toDouble() ?? 0.0, // 추가
      volume: (json['volume'] as num?)?.toInt() ?? 0,              // 추가
    );
  }
}

class WatchlistBriefing {
  final String text;
  final List<String> topIssues;

  WatchlistBriefing({
    required this.text,
    required this.topIssues,
  });

  factory WatchlistBriefing.fromJson(Map<String, dynamic> json) {
    return WatchlistBriefing(
      text: json['text'] as String? ?? '',
      topIssues: (json['topIssues'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }
}
