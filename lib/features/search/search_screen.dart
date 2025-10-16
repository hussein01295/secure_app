import 'package:flutter/material.dart';
import 'search_controller.dart';
import 'user_search_card.dart';

class SearchScreen extends StatefulWidget {
  final String token;
  final String userId;

  const SearchScreen({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SearchLogic {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Ajouter un ami"),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            TextField(
              onChanged: (q) {
                if (q.trim().isEmpty) {
                  setState(() => results = []);
                } else {
                  searchUsers(q.trim());
                }
              },
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                filled: true,
                fillColor: colorScheme.surface,
                prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                hintText: "Rechercher un utilisateur",
                hintStyle: TextStyle(color: colorScheme.primary),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              CircularProgressIndicator(color: colorScheme.primary),
            if (!isLoading)
              Expanded(
                child: results.isEmpty && searchTerm.isNotEmpty
                    ? Center(
                        child: Text(
                          "Aucun utilisateur trouvé.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, idx) {
                          final user = results[idx];
                          return UserSearchCard(
                            displayName: user['displayName'] ?? '',
                            username: user['username'] ?? '',
                            userId: user['_id'] ?? '',
                            currentUserId: widget.userId,
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
