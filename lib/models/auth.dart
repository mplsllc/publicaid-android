class UserData {
  final String id;
  final String email;
  final String? name;
  final String? username;
  final String? avatarUrl;
  final String? createdAt;

  UserData({
    required this.id,
    required this.email,
    this.name,
    this.username,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'].toString(),
      email: json['email'] as String,
      name: json['display_name'] as String? ?? json['name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class AuthState {
  final bool isLoggedIn;
  final String? token;
  final UserData? user;

  const AuthState({
    this.isLoggedIn = false,
    this.token,
    this.user,
  });

  AuthState copyWith({bool? isLoggedIn, String? token, UserData? user}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }
}

class BookmarkItem {
  final String entityId;
  final String name;
  final String? slug;
  final String? city;
  final String? state;
  final String? phone;
  final String? categoryName;
  final String? savedAt;
  // Enriched fields for offline use
  final String? addressLine1;
  final String? addressLine2;
  final String? zip;
  final String? description;
  final String? website;
  final double? lat;
  final double? lng;
  final String? notes;
  final int checkinCount;
  final String? lastVisitAt;

  BookmarkItem({
    required this.entityId,
    required this.name,
    this.slug,
    this.city,
    this.state,
    this.phone,
    this.categoryName,
    this.savedAt,
    this.addressLine1,
    this.addressLine2,
    this.zip,
    this.description,
    this.website,
    this.lat,
    this.lng,
    this.notes,
    this.checkinCount = 0,
    this.lastVisitAt,
  });

  String get fullAddress {
    final parts = <String>[];
    if (addressLine1 != null && addressLine1!.isNotEmpty) parts.add(addressLine1!);
    if (addressLine2 != null && addressLine2!.isNotEmpty) parts.add(addressLine2!);
    final cityStateZip = [city, state, zip]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    if (cityStateZip.isNotEmpty) parts.add(cityStateZip);
    return parts.join(', ');
  }

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      entityId: (json['entity_id'] ?? json['id']).toString(),
      name: json['name'] as String,
      slug: json['slug'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      categoryName: json['category_name'] as String?,
      savedAt: json['saved_at'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      zip: json['zip'] as String?,
      description: json['description'] as String?,
      website: json['website'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      checkinCount: json['checkin_count'] as int? ?? 0,
      lastVisitAt: json['last_visit_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'entity_id': entityId,
        'name': name,
        'slug': slug,
        'city': city,
        'state': state,
        'phone': phone,
        'category_name': categoryName,
        'saved_at': savedAt,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'zip': zip,
        'description': description,
        'website': website,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'notes': notes,
        'checkin_count': checkinCount,
        'last_visit_at': lastVisitAt,
      };
}

class AltchaChallenge {
  final String algorithm;
  final String challenge;
  final String salt;
  final int maxnumber;
  final String signature;

  AltchaChallenge({
    required this.algorithm,
    required this.challenge,
    required this.salt,
    required this.maxnumber,
    required this.signature,
  });

  factory AltchaChallenge.fromJson(Map<String, dynamic> json) {
    return AltchaChallenge(
      algorithm: json['algorithm'] as String,
      challenge: json['challenge'] as String,
      salt: json['salt'] as String,
      maxnumber: (json['maxNumber'] ?? json['maxnumber']) as int,
      signature: json['signature'] as String,
    );
  }
}
