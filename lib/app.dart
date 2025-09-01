import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'ui/home_page.dart';

class StratApp extends StatelessWidget {
  const StratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Стратиграфическая колонка — ГОСТ 21.302-2013',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          fontFamily: 'GOST_Type_A',
        ),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomePage(),
      ),
    );
  }
}