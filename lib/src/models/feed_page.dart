// One page of a list loaded by cursor. nextCursor is null on the last page.
class FeedPage<T> {
  final List<T> items;
  final int? nextCursor;

  const FeedPage(this.items, this.nextCursor);

  factory FeedPage.fromJson(Map<String, dynamic> body, T Function(Map<String, dynamic>) fromJson) {
    return FeedPage(
      (body['data'] as List<dynamic>).map((item) => fromJson(item as Map<String, dynamic>)).toList(),
      body['nextCursor'] as int?,
    );
  }
}
