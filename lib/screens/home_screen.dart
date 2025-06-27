import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, required this.isGuest});

  static bool getIsGuest(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args != null && args['isGuest'] == false ? false : true;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool get isGuest => widget.isGuest;

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Naviguer vers l'écran de connexion
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveIsGuest = HomeScreen.getIsGuest(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          if (!effectiveIsGuest) ...[
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: 'Se déconnecter',
            ),
            const SizedBox(width: 8),
          ],
          if (!effectiveIsGuest)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                // Badge pour les notifications non lues
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('notifications')
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${snapshot.data!.docs.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
      body: Center(
        child: effectiveIsGuest
            ? ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/nfc', arguments: {'isGuest': true});
                },
                child: const Text('Scanner un animal'),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/my_animals');
                    },
                    child: const Text('Mes animaux'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/nfc', arguments: {'isGuest': false});
                    },
                    child: const Text('Scanner un animal'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/map');
                    },
                    child: const Text('Carte'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/history');
                    },
                    child: const Text('Historique'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/market');
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Marché des animaux'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
