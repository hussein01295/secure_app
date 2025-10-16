import 'package:flutter/material.dart'; 
import 'package:silencia/features/chat/widgets/chat_widgets.dart';
import 'package:silencia/features/home/home_navbar.dart';
import 'package:silencia/core/widgets/connection_status_widget.dart';
import '../../core/service/socket_service.dart';
import '../../core/service/language_request_handler.dart';
import '../../core/service/notification_service.dart';
import '../profil/profil_screen.dart';
import '../search/search_screen.dart';
import '../groups/groups_screen.dart';
import '../call/call_history_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String token;
  const HomeScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.token,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with HomeController {
  @override
  void initState() {
    super.initState();
    // Initialisation du socket globalement pour toute l’app
    SocketService().initSocket(widget.token);
    // Envoie le statut online au serveur (juste UNE fois !)
    SocketService().socket.emit('online', widget.userId);

    // Vérifier s'il y a une demande de langue en attente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LanguageRequestHandler().checkPendingLanguageRequest(context);
      // Vérifier s'il y a des notifications de messages en attente
      NotificationService().checkPendingMessageNotifications(context);
    });
  }

  @override
  void dispose() {
    // Déconnexion (offline) lors de la fermeture de l’app
    // SocketService().socket.emit('offline', widget.userId);
    // super.dispose();

      if (SocketService().isReady) {
    final socket = SocketService().socket;
    // ...débranche tes events ici...
    socket.off('event1');
    socket.off('event2');
  }

  super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionStatusWidget(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: pages[selectedIndex],
        bottomNavigationBar: HomeBottomNavBar(
          selectedIndex: selectedIndex,
          onTap: onTabTapped,
        ),
      ),
    );
  }
}

mixin HomeController on State<HomeScreen> {
  late final List<Widget> pages;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final home = widget;
    // PAS de emit('online', userId) ici, déjà fait dans HomeScreen.initState

    pages = [
      ChatListView(token: home.token, userId: home.userId),
      const GroupsScreen(),
      const CallHistoryScreen(),
      SearchScreen(token: home.token, userId: home.userId),
      ProfileScreen(
        username: home.username,
        isCurrentUser: true,
        userId: home.userId,
      ),
    ];
  }

  void onTabTapped(int index) {
    if (!mounted) return;
    setState(() => selectedIndex = index);
  }
}
