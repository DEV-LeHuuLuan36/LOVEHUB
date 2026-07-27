import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    super.displayName,
    super.photoUrl,
    super.coupleId,
    super.bio,
  });

  factory AppUserModel.fromFirebaseUser(User user, {String? coupleId}) {
    return AppUserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      coupleId: coupleId,
    );
  }

  factory AppUserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUserModel(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      coupleId: data['coupleId'] as String?,
      bio: data['bio'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (coupleId != null) 'coupleId': coupleId,
      if (bio != null) 'bio': bio,
    };
  }

  AppUserModel copyWithAppUser({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? coupleId,
    String? bio,
  }) {
    return AppUserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      coupleId: coupleId ?? this.coupleId,
      bio: bio ?? this.bio,
    );
  }
}
