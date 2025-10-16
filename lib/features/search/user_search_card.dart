import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserSearchCard extends StatelessWidget {
  final String displayName;
  final String username;
  final String userId;
  final String currentUserId;

  const UserSearchCard({
    super.key,
    required this.displayName,
    required this.username,
    required this.userId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrentUser = userId == currentUserId;

    return Card(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary,
          child: Icon(Icons.person, color: colorScheme.onPrimary),
        ),
        title: Text(
          displayName.isNotEmpty ? displayName : username,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '@$username',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.info_outline, color: colorScheme.primary),
          onPressed: () {
            context.push('/profile', extra: {
              'username': username,
              'displayName': displayName,
              'userId': userId,
              'isCurrentUser': isCurrentUser,
            });
          },
        ),
        onTap: () {
          context.push('/profile', extra: {
            'username': username,
            'displayName': displayName,
            'userId': userId,
            'isCurrentUser': isCurrentUser,
          });
        },
      ),
    );
  }
}
