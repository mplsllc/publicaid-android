class DataQuality {
  final double? freshnessScore;
  final int? sourceCount;
  final bool isVerified;
  final String? lastVerifiedAt;
  final String? updatedAt;
  final int communityFlags;
  final bool hasActiveFlags;

  DataQuality({
    this.freshnessScore,
    this.sourceCount,
    this.isVerified = false,
    this.lastVerifiedAt,
    this.updatedAt,
    this.communityFlags = 0,
    this.hasActiveFlags = false,
  });

  factory DataQuality.fromJson(Map<String, dynamic> json) {
    return DataQuality(
      freshnessScore: (json['freshness_score'] as num?)?.toDouble(),
      sourceCount: json['source_count'] as int?,
      isVerified: json['is_verified'] as bool? ?? false,
      lastVerifiedAt: json['last_verified_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      communityFlags: json['community_flags'] as int? ?? 0,
      hasActiveFlags: json['has_active_flags'] as bool? ?? false,
    );
  }
}

class EntityCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;

  EntityCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
  });

  factory EntityCategory.fromJson(Map<String, dynamic> json) {
    return EntityCategory(
      id: json['id'].toString(),
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }
}

class Entity {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? phone;
  final String? website;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? zip;
  final String country;
  final double? lat;
  final double? lng;
  final List<String> languages;
  final List<String> accessibility;
  final String? alternateName;
  final String? intakePhone;
  final List<String> paymentTypes;
  final List<String> populationsServed;
  final List<String> ageGroups;
  final List<String> serviceSettings;
  final List<String> accreditations;
  final List<EntityCategory> categories;
  final double? distanceMiles;
  final String? updatedAt;
  final DataQuality? dataQuality;

  Entity({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.phone,
    this.website,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.zip,
    this.country = 'US',
    this.lat,
    this.lng,
    this.languages = const [],
    this.accessibility = const [],
    this.alternateName,
    this.intakePhone,
    this.paymentTypes = const [],
    this.populationsServed = const [],
    this.ageGroups = const [],
    this.serviceSettings = const [],
    this.accreditations = const [],
    this.categories = const [],
    this.distanceMiles,
    this.updatedAt,
    this.dataQuality,
  });

  String get fullAddress {
    final parts = <String>[];
    if (addressLine1 != null && addressLine1!.isNotEmpty) {
      parts.add(addressLine1!);
    }
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    final cityStateZip = <String>[];
    if (city != null && city!.isNotEmpty) cityStateZip.add(city!);
    if (state != null && state!.isNotEmpty) cityStateZip.add(state!);
    if (zip != null && zip!.isNotEmpty) cityStateZip.add(zip!);
    if (cityStateZip.isNotEmpty) parts.add(cityStateZip.join(', '));
    return parts.join('\n');
  }

  String? get distanceText {
    if (distanceMiles == null) return null;
    if (distanceMiles! < 0.1) return '< 0.1 mi';
    return '${distanceMiles!.toStringAsFixed(1)} mi';
  }

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'].toString(),
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zip: json['zip'] as String?,
      country: json['country'] as String? ?? 'US',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      languages: _toStringList(json['languages']),
      accessibility: _toStringList(json['accessibility']),
      alternateName: json['alternate_name'] as String?,
      intakePhone: json['intake_phone'] as String?,
      paymentTypes: _toStringList(json['payment_types']),
      populationsServed: _toStringList(json['populations_served']),
      ageGroups: _toStringList(json['age_groups']),
      serviceSettings: _toStringList(json['service_settings']),
      accreditations: _toStringList(json['accreditations']),
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) => EntityCategory.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] as String?,
      dataQuality: json['data_quality'] != null
          ? DataQuality.fromJson(json['data_quality'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'phone': phone,
        'website': website,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
        'lat': lat,
        'lng': lng,
        'languages': languages,
        'accessibility': accessibility,
        'alternate_name': alternateName,
        'intake_phone': intakePhone,
        'payment_types': paymentTypes,
        'populations_served': populationsServed,
        'age_groups': ageGroups,
        'service_settings': serviceSettings,
        'accreditations': accreditations,
        'categories': categories.map((c) => {
              'id': c.id,
              'name': c.name,
              'slug': c.slug,
            }).toList(),
        'distance_miles': distanceMiles,
        'updated_at': updatedAt,
      };

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}

class EntityService {
  final String id;
  final String name;
  final String? description;
  final String? url;
  final String? eligibility;
  final String? fees;
  final int? sortOrder;

  EntityService({
    required this.id,
    required this.name,
    this.description,
    this.url,
    this.eligibility,
    this.fees,
    this.sortOrder,
  });

  factory EntityService.fromJson(Map<String, dynamic> json) {
    return EntityService(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      url: json['url'] as String?,
      eligibility: json['eligibility'] as String?,
      fees: json['fees'] as String?,
      sortOrder: json['sort_order'] as int?,
    );
  }
}

class EntityHours {
  final int dayOfWeek;
  final String? opens;
  final String? closes;
  final bool closed;

  EntityHours({
    required this.dayOfWeek,
    this.opens,
    this.closes,
    this.closed = false,
  });

  String get dayName {
    switch (dayOfWeek) {
      case 0:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return '';
    }
  }

  String get hoursText {
    if (closed) return 'Closed';
    if (opens == null || closes == null) return 'N/A';
    return '$opens - $closes';
  }

  factory EntityHours.fromJson(Map<String, dynamic> json) {
    return EntityHours(
      dayOfWeek: json['day_of_week'] as int,
      opens: json['open_time'] as String?,
      closes: json['close_time'] as String?,
      closed: json['is_closed'] as bool? ?? false,
    );
  }
}
