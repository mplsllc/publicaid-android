class UserData {
  final int id;
  final String email;
  final String? name;
  final String? createdAt;

  UserData({
    required this.id,
    required this.email,
    this.name,
    this.createdAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String?,
      createdAt: json['created_at'] as String?,
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
  final String? city;
  final String? state;
  final String? phone;
  final String? categoryName;
  final String? savedAt;

  BookmarkItem({
    required this.entityId,
    required this.name,
    this.city,
    this.state,
    this.phone,
    this.categoryName,
    this.savedAt,
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      entityId: (json['entity_id'] ?? json['id']).toString(),
      name: json['name'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      categoryName: json['category_name'] as String?,
      savedAt: json['saved_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'entity_id': entityId,
        'name': name,
        'city': city,
        'state': state,
        'phone': phone,
        'category_name': categoryName,
        'saved_at': savedAt,
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
      maxnumber: json['maxnumber'] as int,
      signature: json['signature'] as String,
    );
  }
}
