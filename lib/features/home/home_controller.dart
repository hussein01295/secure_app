import 'package:flutter/material.dart';
import 'package:silencia/features/chat/widgets/chat_widgets.dart';
import 'home_screen.dart';
import '../../core/service/socket_service.dart'; 
import '../profil/profil_screen.dart';
import '../search/search_screen.dart';

mixin HomeController on State<HomeScreen> {
  late final List<Widget> pages;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final home = widget;

    SocketService().initSocket(home.token);

    pages = [
      ChatListView(token: home.token, userId: home.userId),
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
