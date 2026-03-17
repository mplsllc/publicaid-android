class PlanItem {
  final String id;
  final String entityId;
  final int sortOrder;
  final String notes;
  final bool completed;
  final String? completedAt;
  final String? createdAt;
  final String entityName;
  final String? city;
  final String? state;
  final String? phone;
  final String? addressLine1;

  PlanItem({
    required this.id,
    required this.entityId,
    required this.sortOrder,
    this.notes = '',
    this.completed = false,
    this.completedAt,
    this.createdAt,
    required this.entityName,
    this.city,
    this.state,
    this.phone,
    this.addressLine1,
  });

  PlanItem copyWith({
    String? notes,
    bool? completed,
    String? completedAt,
    int? sortOrder,
  }) {
    return PlanItem(
      id: id,
      entityId: entityId,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      entityName: entityName,
      city: city,
      state: state,
      phone: phone,
      addressLine1: addressLine1,
    );
  }

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: json['id'].toString(),
      entityId: json['entity_id'].toString(),
      sortOrder: json['sort_order'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
      createdAt: json['created_at'] as String?,
      entityName: json['entity_name'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      addressLine1: json['address_line1'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_id': entityId,
        'sort_order': sortOrder,
        'notes': notes,
        'completed': completed,
        'completed_at': completedAt,
        'created_at': createdAt,
        'entity_name': entityName,
        'city': city,
        'state': state,
        'phone': phone,
        'address_line1': addressLine1,
      };
}
