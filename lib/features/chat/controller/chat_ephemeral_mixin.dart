import 'package:flutter/material.dart';
import 'package:silencia/core/service/ephemeral_service.dart';
import 'package:silencia/features/chat/controller/chat_vars.dart';

mixin ChatEphemeralMixin<T extends StatefulWidget> on ChatVars<T> {
  Future<void> loadEphemeralSettings() async {
    try {
      final settings = await EphemeralService.getSettings(relationId);
      if (mounted) {
        setState(() {
          ephemeralSettings = settings;
          ephemeralEnabled = settings['enabled'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des paramètres éphémères: $e');
      if (mounted) {
        setState(() {
          ephemeralSettings = null;
          ephemeralEnabled = false;
        });
      }
    }
  }

  Future<void> reloadEphemeralSettings() async { await loadEphemeralSettings(); }
}
