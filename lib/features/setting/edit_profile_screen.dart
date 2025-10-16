import 'package:flutter/material.dart';
import 'package:silencia/core/theme/theme_manager.dart';
import 'package:silencia/core/widgets/cached_profile_avatar.dart';


class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String displayName = "Alice";
  String username = "alice";
  String bio = "Décris-toi ici...";

  @override
  Widget build(BuildContext context) {
    final themeManager = globalThemeManager;


    return Scaffold(
      backgroundColor: themeManager.getBackgroundColor(),
      appBar: AppBar(
        backgroundColor: themeManager.getSurfaceColor(),
        elevation: 0,
        title: Text(
          "Modifier le profil",
          style: TextStyle(color: themeManager.accentColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: themeManager.accentColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CachedProfileAvatar(
                      username: "Utilisateur", // TODO: Récupérer le vrai nom d'utilisateur
                      radius: 45,
                    ),
                    Positioned(
                      bottom: 4, right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: themeManager.accentColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.edit, color: themeManager.getBackgroundColor(), size: 20),
                          onPressed: () {
                            // Changer la photo de profil
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _profileField(
                label: "Nom affiché",
                icon: Icons.person,
                initialValue: displayName,
                onSaved: (val) => displayName = val ?? "",
                validator: (val) => (val == null || val.isEmpty) ? "Champ requis" : null,
              ),
              const SizedBox(height: 16),
              _profileField(
                label: "Nom d'utilisateur",
                icon: Icons.alternate_email,
                initialValue: username,
                onSaved: (val) => username = val ?? "",
                validator: (val) =>
                    (val == null || val.isEmpty) ? "Champ requis" : null,
                readOnly: true, // (tu peux passer à false si édition du @username possible)
              ),
              const SizedBox(height: 16),
              _profileField(
                label: "Bio",
                icon: Icons.info_outline_rounded,
                initialValue: bio,
                onSaved: (val) => bio = val ?? "",
                maxLines: 2,
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() == true) {
                    _formKey.currentState?.save();
                    // Appelle ici ta logique d'update profil
                    Navigator.of(context).pop(); // Retour après sauvegarde
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.accentColor,
                  foregroundColor: themeManager.getBackgroundColor(),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text("Enregistrer"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileField({
    required String label,
    required IconData icon,
    required String initialValue,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onSaved: onSaved,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.cyanAccent),
        filled: true,
        fillColor: const Color(0xFF19232b),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
