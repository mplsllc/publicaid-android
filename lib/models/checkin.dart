class CheckinItem {
  final String id;
  final String visitedAt;
  final String? note;

  CheckinItem({
    required this.id,
    required this.visitedAt,
    this.note,
  });

  factory CheckinItem.fromJson(Map<String, dynamic> json) {
    return CheckinItem(
      id: json['id'].toString(),
      visitedAt: json['visited_at'] as String,
      note: json['note'] as String?,
    );
  }
}
