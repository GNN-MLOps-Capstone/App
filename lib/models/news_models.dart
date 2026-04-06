class NewsRecommendationItem {
  final int newsId;
  final String title;
  final String summary;
  final DateTime? pubDate;
  final String? path;
  final String? stockName;
  final String? stockChange;
  final bool? stockUp;
  final bool isPlaceholder;

  const NewsRecommendationItem({
    required this.newsId,
    required this.title,
    required this.summary,
    this.pubDate,
    this.path,
    this.stockName,
    this.stockChange,
    this.stockUp,
    this.isPlaceholder = false,
  });

  factory NewsRecommendationItem.fromJson(Map<String, dynamic> json) {
    return NewsRecommendationItem(
      newsId: json['news_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      pubDate: json['pub_date'] != null
          ? DateTime.tryParse(json['pub_date'] as String)
          : null,
      path: json['path'] as String?,
      stockName: json['stock_name'] as String?,
      stockChange: json['stock_change'] as String?,
      stockUp: json['stock_up'] as bool?,
      isPlaceholder: json['is_placeholder'] as bool? ?? false,
    );
  }
}

class NewsRecommendationPage {
  final int userId;
  final String requestId;
  final String source;
  final int page;
  final String? nextCursor;
  final int servedCount;
  final bool logged;
  final List<NewsRecommendationItem> items;

  const NewsRecommendationPage({
    required this.userId,
    required this.requestId,
    required this.source,
    required this.page,
    required this.nextCursor,
    required this.servedCount,
    required this.logged,
    required this.items,
  });

  factory NewsRecommendationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return NewsRecommendationPage(
      userId: json['user_id'] as int? ?? 0,
      requestId: json['request_id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      page: json['page'] as int? ?? 1,
      nextCursor: json['next_cursor'] as String?,
      servedCount: json['served_count'] as int? ?? 0,
      logged: json['logged'] as bool? ?? false,
      items: rawItems
          .map(
            (item) => NewsRecommendationItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class NewsDetailStockItem {
  final String stockId;
  final String stockName;
  final String? stockChange;
  final bool? stockUp;

  const NewsDetailStockItem({
    required this.stockId,
    required this.stockName,
    this.stockChange,
    this.stockUp,
  });

  factory NewsDetailStockItem.fromJson(Map<String, dynamic> json) {
    return NewsDetailStockItem(
      stockId: json['stock_id'] as String? ?? '',
      stockName: (json['stock_name'] as String? ?? '').trim(),
      stockChange: json['stock_change'] as String?,
      stockUp: json['stock_up'] as bool?,
    );
  }
}

class NewsDetailItem {
  final int newsId;
  final String title;
  final String summary;
  final String body;
  final DateTime? pubDate;
  final String? url;
  final String? sentiment;
  final List<String> keywords;
  final List<NewsDetailStockItem> relatedStocks;
  final String? stockName;
  final String? stockChange;
  final bool? stockUp;

  const NewsDetailItem({
    required this.newsId,
    required this.title,
    required this.summary,
    required this.body,
    this.pubDate,
    this.url,
    this.sentiment,
    this.keywords = const [],
    this.relatedStocks = const [],
    this.stockName,
    this.stockChange,
    this.stockUp,
  });

  factory NewsDetailItem.fromRecommendationItem(NewsRecommendationItem item) {
    final trimmedStockName = item.stockName?.trim();
    return NewsDetailItem(
      newsId: item.newsId,
      title: item.title,
      summary: item.summary,
      body: item.summary,
      pubDate: item.pubDate,
      relatedStocks: trimmedStockName?.isNotEmpty == true
          ? [
              NewsDetailStockItem(
                stockId: '',
                stockName: trimmedStockName!,
                stockChange: item.stockChange,
                stockUp: item.stockUp,
              ),
            ]
          : const [],
      stockName: item.stockName,
      stockChange: item.stockChange,
      stockUp: item.stockUp,
    );
  }

  factory NewsDetailItem.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'] as List<dynamic>? ?? const [];
    final rawRelatedStocks =
        json['related_stocks'] as List<dynamic>? ?? const [];
    final relatedStocks = rawRelatedStocks
        .map(
          (stock) => NewsDetailStockItem.fromJson(
            Map<String, dynamic>.from(stock as Map),
          ),
        )
        .where((stock) => stock.stockName.trim().isNotEmpty)
        .toList();
    return NewsDetailItem(
      newsId: json['news_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      body: json['body'] as String? ?? '',
      pubDate: json['pub_date'] != null
          ? DateTime.tryParse(json['pub_date'] as String)
          : null,
      url: json['url'] as String?,
      sentiment: json['sentiment'] as String?,
      keywords: rawKeywords.map((keyword) => keyword.toString()).toList(),
      relatedStocks: relatedStocks,
      stockName: json['stock_name'] as String?,
      stockChange: json['stock_change'] as String?,
      stockUp: json['stock_up'] as bool?,
    );
  }
}
