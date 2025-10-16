import 'package:flutter/material.dart';

class HomeBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const HomeBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Utilisation du thème pour la couleur
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BottomNavigationBar(
      backgroundColor: colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: isDark ? Colors.white54 : Colors.black45,
      currentIndex: selectedIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groupes'),
        BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Appels'),
        BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Ajouter'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
      ],
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    );
  }
}
