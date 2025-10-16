import 'package:flutter/material.dart';
import 'package:silencia/features/profil/profile_me_controller.dart';
import 'package:silencia/features/profil/profile_view.dart';

class ProfileScreen extends StatelessWidget {
  final String username;
  final String? displayName;
  final bool isCurrentUser;
  final String? userId;

  const ProfileScreen({
    super.key,
    required this.username,
    this.displayName,
    required this.isCurrentUser,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileView(
      username: username,
      displayName: displayName,
      isCurrentUser: isCurrentUser,
      userId: userId,
      controller: isCurrentUser
          ? ProfileMeController()
          : ProfileUserController(userId: userId),
    );
  }
}
