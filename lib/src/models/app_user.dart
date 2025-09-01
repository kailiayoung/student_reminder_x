class AppUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String courseGroup; // 'web' | 'mobile'
  final String email;
  final String phone;
  final String? gender;
  final String? bio;
  final String? photoUrl;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.courseGroup,
    required this.email,
    required this.phone,
    this.gender,
    this.bio,
    this.photoUrl,
    this.createdAt,
  });

  //From Firebase to Dart
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      courseGroup: data['courseGroup'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      gender: data['gender'],
      bio: data['bio'],
      createdAt: (data['createdAt']?.toDate()) as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
    'firstName': firstName,
    'lastName': lastName,
    'courseGroup': courseGroup,
    'email': email,
    'phone': phone,
    'gender': gender,
    'bio': bio,
    'createdAt': createdAt,
  };

  String get displayName => '$firstName $lastName';
}
