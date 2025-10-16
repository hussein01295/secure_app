import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:silencia/core/config/api_config.dart';
import 'package:silencia/core/service/auth_service.dart';
import 'search_screen.dart';

mixin SearchLogic on State<SearchScreen> {
  List<dynamic> results = [];
  bool isLoading = false;
  String searchTerm = "";

  Future<void> searchUsers(String query) async {
    // Capturer la référence avant les opérations async
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      isLoading = true;
      searchTerm = query;
    });

    try {
      final headers = await AuthService.getAuthorizedHeaders(context: context);
      if (headers == null) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/relations/search?q=$query');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          results = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception("Erreur ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        results = [];
        isLoading = false;
      });

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text("Erreur recherche : $e")),
        );
      }
    }
  }
}
