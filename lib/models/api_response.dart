class ApiResponse<T> {
  final T data;
  final ApiMeta? meta;

  ApiResponse({required this.data, this.meta});
}

class ApiMeta {
  final int total;
  final int limit;
  final int offset;

  ApiMeta({required this.total, required this.limit, required this.offset});

  factory ApiMeta.fromJson(Map<String, dynamic> json) {
    return ApiMeta(
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
    );
  }
}
