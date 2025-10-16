import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:silencia/core/auth/auth_provider.dart';
import 'package:silencia/core/services/key_backup_service.dart';
import 'package:silencia/features/chat/chat_screen.dart';
import 'package:silencia/features/home/home_screen.dart';
import 'package:silencia/features/login/login_screen.dart';
import 'package:silencia/features/profil/profile_conversation_screen.dart';
import 'package:silencia/features/profil/profile_me_controller.dart';
import 'package:silencia/features/profil/profile_view.dart';
import 'package:silencia/features/register/register_screen.dart';
import 'package:silencia/features/backup/backup_choice_screen.dart';
import 'package:silencia/features/backup/backup_success_screen.dart';
import 'package:silencia/features/backup/local_backup_choice_screen.dart';
import 'package:silencia/features/backup/local_backup_restore_screen.dart';
import 'package:silencia/features/backup/local_backup_success_screen.dart';
import 'package:silencia/features/backup/models/master_password_args.dart';
import 'package:silencia/features/backup/models/recovery_flow_data.dart';
import 'package:silencia/features/backup/recovery_phrase_display_screen.dart';
import 'package:silencia/features/backup/recovery_phrase_verify_screen.dart';
import 'package:silencia/features/backup/restore_backup_screen.dart';
import 'package:silencia/features/backup/setup_both_screen.dart';
import 'package:silencia/features/backup/setup_master_password_screen.dart';
import 'package:silencia/features/backup/setup_recovery_phrase_screen.dart';
import 'package:silencia/features/setting/change_password_screen.dart';
import 'package:silencia/features/setting/edit_profile_screen.dart';
import 'package:silencia/features/setting/settings_screen.dart';
import 'package:silencia/features/splash/splash_screen.dart';
import 'package:silencia/features/groups/groups_screen.dart';
import 'package:silencia/features/groups/group_chat_screen.dart';
import 'package:silencia/features/call/call_screen.dart';
import 'package:silencia/features/call/call_history_screen.dart';
import 'package:silencia/features/call/call_demo_screen.dart';
import 'package:silencia/features/call/models/call_state.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/splash'),
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        return HomeScreen(
          token: args?['token'],
          userId: args?['userId'],
          username: args?['username'],
        );
      },
      redirect: (context, state) async {
        if (!await AuthProvider.isLoggedIn()) {
          return '/login';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ProfileView(
          username: args['username'],
          displayName: args['displayName'],
          isCurrentUser: args['isCurrentUser'] ?? false,
          userId: args['userId'],
          controller: (args['isCurrentUser'] ?? false)
              ? ProfileMeController()
              : ProfileUserController(userId: args['userId']),
        );
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ChatScreen(
          contactName: args['contactName'],
          contactId: args['contactId'],
          token: args['token'],
          userId: args['userId'],
          relationId: args['relationId'],
        );
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: 'change-password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/conversation-info',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};

        // 🔍 DEBUG: Logs pour diagnostiquer le problème
        debugPrint('🔍 DEBUG: Route /conversation-info appelée');
        debugPrint('🔍 DEBUG: args = $args');
        debugPrint('🔍 DEBUG: args[relationId] = ${args['relationId']}');
        debugPrint(
          '🔍 DEBUG: args[relationId].runtimeType = ${args['relationId']?.runtimeType}',
        );

        return ProfileConversationScreen(
          contactName: args['contactName'] ?? '',
          username: args['username'] ?? '',
          isOnline: args['isOnline'] ?? false,
          lastSeen: args['lastSeen'] ?? '',
          secureStatus: args['secureStatus'] ?? '',
          exchangedMessages: args['exchangedMessages'] ?? 0,
          lastMessage: args['lastMessage'] ?? '',
          lastMessageDate: args['lastMessageDate'] ?? '',
          sharedPhotos: (args['sharedPhotos'] ?? <String>[]).cast<String>(),
          relationId: args['relationId'], // 🔥 AJOUT: relationId manquant
        );
      },
    ),
    GoRoute(
      path: '/groups',
      builder: (context, state) => const GroupsScreen(),
      redirect: (context, state) async {
        if (!await AuthProvider.isLoggedIn()) {
          return '/login';
        }
        return null;
      },
    ),

    GoRoute(
      path: '/backup-choice',
      builder: (context, state) => const BackupChoiceScreen(),
    ),
    GoRoute(
      path: '/backup/setup-master-password',
      builder: (context, state) {
        final MasterPasswordScreenArgs args =
            state.extra as MasterPasswordScreenArgs? ??
            const MasterPasswordScreenArgs(
              mode: KeyBackupService.backupModePassword,
            );
        return SetupMasterPasswordScreen(args: args);
      },
    ),
    GoRoute(
      path: '/backup/setup-recovery-phrase',
      builder: (context, state) => const SetupRecoveryPhraseScreen(),
    ),
    GoRoute(
      path: '/backup/setup-both',
      builder: (context, state) => const SetupBothScreen(),
    ),
    GoRoute(
      path: '/backup/recovery-phrase-display',
      builder: (context, state) {
        final RecoveryFlowData data = state.extra as RecoveryFlowData;
        return RecoveryPhraseDisplayScreen(data: data);
      },
    ),
    GoRoute(
      path: '/backup/recovery-phrase-verify',
      builder: (context, state) {
        final RecoveryFlowData data = state.extra as RecoveryFlowData;
        return RecoveryPhraseVerifyScreen(data: data);
      },
    ),
    GoRoute(
      path: '/backup/success',
      builder: (context, state) => const BackupSuccessScreen(),
    ),
    GoRoute(
      path: '/restore-backup',
      builder: (context, state) => const RestoreBackupScreen(),
    ),
    GoRoute(
      path: '/local-backup-choice',
      builder: (context, state) => const LocalBackupChoiceScreen(),
    ),
    GoRoute(
      path: '/local-backup-success',
      builder: (context, state) => const LocalBackupSuccessScreen(),
    ),
    GoRoute(
      path: '/local-backup-restore',
      builder: (context, state) => const LocalBackupRestoreScreen(),
    ),
    GoRoute(
      path: '/group-chat',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return GroupChatScreen(
          groupId: args['groupId'] ?? '',
          groupName: args['groupName'] ?? 'Groupe',
        );
      },
      redirect: (context, state) async {
        if (!await AuthProvider.isLoggedIn()) {
          return '/login';
        }
        return null;
      },
    ),

    // Routes pour les appels
    GoRoute(
      path: '/call',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return CallScreen(
          contactName: args['contactName'] ?? '',
          contactId: args['contactId'] ?? '',
          contactAvatar: args['contactAvatar'],
          callType: args['callType'] ?? CallType.audio,
          isIncoming: args['isIncoming'] ?? false,
          callId: args['callId'],
        );
      },
      redirect: (context, state) async {
        if (!await AuthProvider.isLoggedIn()) {
          return '/login';
        }
        return null;
      },
    ),

    GoRoute(
      path: '/call-history',
      builder: (context, state) => const CallHistoryScreen(),
      redirect: (context, state) async {
        if (!await AuthProvider.isLoggedIn()) {
          return '/login';
        }
        return null;
      },
    ),

    GoRoute(
      path: '/call-demo',
      builder: (context, state) => const CallDemoScreen(),
      redirect: (context, state) async {
        if (!await AuthProvider.isLoggedIn()) {
          return '/login';
        }
        return null;
      },
    ),
  ],
);
