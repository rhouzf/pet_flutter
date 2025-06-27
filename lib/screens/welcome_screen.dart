import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Bienvenue !'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final cred = await FirebaseAuth.instance.signInAnonymously();
                  final uid = cred.user?.uid ?? 'Erreur UID';
                  // Affiche l'UID guest pour vérification
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connecté en guest Firebase, UID: $uid')),
                  );
                  Navigator.pushReplacementNamed(
                    context,
                    '/home',
                    arguments: {'isGuest': true, 'uid': uid},
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur connexion guest : '
                        + (e.toString())),
                    )
                  );
                }
              },
              child: const Text('Continuer en tant que Guest'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}
