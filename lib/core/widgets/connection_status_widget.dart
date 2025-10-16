import 'package:flutter/material.dart';

/// Widget simplifié qui retourne directement l'enfant sans barre de statut
class ConnectionStatusWidget extends StatelessWidget {
  final Widget child;
  final bool showDetailedStatus;
  
  const ConnectionStatusWidget({
    super.key,
    required this.child,
    this.showDetailedStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    // Retourner directement l'enfant sans aucune logique de statut
    return child;
  }
}
