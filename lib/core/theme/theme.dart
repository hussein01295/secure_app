import 'package:flutter/material.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);
final material3Notifier = ValueNotifier<bool>(false);

ThemeData lightTheme({bool useMaterial3 = false}) => ThemeData(
  useMaterial3: useMaterial3,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    iconTheme: IconThemeData(color: Colors.cyan),
    titleTextStyle: TextStyle(
      color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 20,
    ),
    elevation: 0,
  ),
  colorScheme: ColorScheme.light(
    primary: Colors.cyan,
    secondary: Colors.cyan,
    surface: Colors.white,
  ),
  cardColor: Colors.grey[100],
  iconTheme: const IconThemeData(color: Colors.cyan),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[100],
    prefixIconColor: Colors.cyan,
    hintStyle: const TextStyle(color: Colors.cyan),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.cyan, width: 1.4),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.cyan,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
    labelLarge: TextStyle(color: Colors.cyan),
  ),
);

ThemeData darkTheme({bool useMaterial3 = false}) => ThemeData(
  useMaterial3: useMaterial3,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121c23),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF19232b),
    iconTheme: IconThemeData(color: Colors.cyanAccent),
    titleTextStyle: TextStyle(
      color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 20),
    elevation: 0,
  ),
  colorScheme: ColorScheme.dark(
    primary: Colors.cyanAccent,
    secondary: Colors.cyanAccent,
    surface: const Color(0xFF19232b),
  ),
  cardColor: const Color(0xFF19232b),
  iconTheme: const IconThemeData(color: Colors.cyanAccent),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF19232b),
    prefixIconColor: Colors.cyanAccent,
    hintStyle: const TextStyle(color: Colors.cyanAccent),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.4),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.cyanAccent,
      foregroundColor: const Color(0xFF121c23),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
    labelLarge: TextStyle(color: Colors.cyanAccent),
  ),
);
