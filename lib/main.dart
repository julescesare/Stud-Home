import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:stud_home/controllers/property_controller.dart';
import 'package:stud_home/views/screens/search/search_screen.dart';

import 'controllers/auth_controller.dart';
import 'views/screens/auth/login_screen.dart';

Future<void> main() async {
  // Nécessaire avant tout appel Firebase, car on utilise `await` avant runApp.
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const StudHomeApp());
}

class StudHomeApp extends StatelessWidget {
  const StudHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // On centralise ici tous les Controllers (ChangeNotifier) de
      // l'application.
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => PropertyController()),
      ],
      child: MaterialApp(
        title: "Stud'Home",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Outfit',
          colorSchemeSeed: const Color(
            0xFF4F46E5,
          ), // Indigo, cohérent avec les maquettes
          scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        ),
        // AuthGate décide, au démarrage, si on affiche l'écran de connexion
        // ou l'app principale, selon l'état de la session Firebase.
        home: const AuthGate(),
      ),
    );
  }
}

/// Point de bascule entre "utilisateur non connecté" et "utilisateur connecté".
///
/// Écoute l'AuthController : dès que `currentUser` change (connexion,
/// déconnexion), ce widget se reconstruit et affiche le bon écran.
/// C'est la seule vue qui a besoin de connaître cette logique de routage —
/// les autres écrans n'ont pas à s'en soucier.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.currentUser != null) {
      return const Scaffold(body: SearchScreen());
    }

    return const LoginScreen();
  }
}
