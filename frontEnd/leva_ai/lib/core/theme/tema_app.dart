import 'package:flutter/material.dart';
import '../constants/constantes_app.dart';

abstract final class TemaApp {
  static ThemeData get claro => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ConstantesApp.fundo,
    colorScheme: ColorScheme.fromSeed(seedColor: ConstantesApp.azulPrincipal),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.white,
    ),
  );
}
