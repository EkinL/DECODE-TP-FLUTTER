class PaginatedResponse<T> {
  final int count;
  final List<T> rows;

  const PaginatedResponse({
    required this.count,
    required this.rows,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PaginatedResponse(
      count: json['count'],
      rows: json['rows'].map<T>((e) => fromJson(e)).toList(),
    );
  }
}
