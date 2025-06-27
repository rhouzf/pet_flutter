import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/animal.dart';
import 'sell_animal_screen.dart';

class DetailsScreen extends StatefulWidget {
  final bool isGuest;
  const DetailsScreen({super.key, required this.isGuest});

  static bool getIsGuest(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args != null && args['isGuest'] == false ? false : true;
  }

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final nfcText = args != null && args['nfcText'] != null ? args['nfcText'] as String : '';
    
    debugPrint('Arguments de navigation: $args');
    debugPrint('Code NFC: $nfcText');
    debugPrint('Utilisateur actuel: ${FirebaseAuth.instance.currentUser?.uid}');
    
    return Scaffold(
      appBar: AppBar(title: const Text("Détails de l'animal")),
      body: nfcText.isEmpty
          ? const Center(child: Text('Aucun code NFC lu.'))
          : FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collectionGroup('animals')
                  .where('nfcCode', isEqualTo: nfcText)
                  .limit(1)
                  .get()
                  .catchError((e) {
                    print('Erreur Firestore : $e');
                  }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Aucun animal trouvé pour ce code NFC.'));
                }
                final animal = snapshot.data!.docs.first;
                final animalData = animal.data() as Map<String, dynamic>;
                final userRef = animal.reference.parent.parent;
                
                debugPrint('Données de l\'animal: $animalData');
                debugPrint('Référence de l\'animal: ${animal.reference.path}');
                debugPrint('Référence de l\'utilisateur: ${userRef?.path}');

                return FutureBuilder<DocumentSnapshot>(
                  future: userRef?.get(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!userSnap.hasData || !userSnap.data!.exists) {
                      return const Center(child: Text('Propriétaire inconnu.'));
                    }

                    final userData = userSnap.data!.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Nom de l\'animal : ${animalData['nom'] ?? '-'}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Text('Âge : ${animalData['age'] ?? '-'}'),
                              const Divider(height: 30),
                              Text('Propriétaire : ${userData['nom'] ?? '-'} ${userData['prenom'] ?? ''}'),
                              Text('Contact : ${userData['email'] ?? '-'}'),
                              // Section pour les propriétaires
                              Builder(
                                builder: (context) {
                                  debugPrint('UID Utilisateur actuel: ${FirebaseAuth.instance.currentUser?.uid}');
                                  debugPrint('UID Propriétaire animal: ${animal.reference.parent.parent?.id}');
                                  debugPrint('isForSale: ${animalData['isForSale']}');
                                  debugPrint('Prix: ${animalData['price']}');
                                  return const SizedBox.shrink();
                                },
                              ),
                              if (FirebaseAuth.instance.currentUser?.uid == animal.reference.parent.parent?.id) ...[
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: () => _navigateToSellScreen(context, animal.reference, animalData),
                                  icon: const Icon(Icons.sell, size: 18),
                                  label: Text(animalData['isForSale'] == true 
                                      ? 'Modifier la vente' 
                                      : 'Mettre en vente'),
                                ),
                                if (animalData['isForSale'] == true) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Prix : ${animalData['price']} €',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ] else if (animalData['isForSale'] == true) ...[
                                // Section pour les acheteurs potentiels
                                const SizedBox(height: 20),
                                Text(
                                  'À vendre : ${animalData['price']} €',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => _buyAnimal(context, animal.reference, animalData, userData),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Acheter cet animal'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _buyAnimal(
    BuildContext context,
    DocumentReference animalRef,
    Map<String, dynamic> animalData,
    Map<String, dynamic> ownerData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour acheter un animal')),
      );
      return;
    }

    // Vérifier que l'utilisateur n'achète pas son propre animal
    if (currentUser.uid == animalRef.parent.parent?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous êtes déjà le propriétaire de cet animal')),
      );
      return;
    }

    try {
      // Afficher une boîte de dialogue de confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer l\'achat'),
          content: Text('Voulez-vous vraiment acheter ${animalData['nom']} pour ${animalData['price']} € ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Récupérer les informations de l'acheteur
      final buyerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!buyerDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }

      final buyerData = buyerDoc.data()!;

      // Mettre à jour le document de l'animal avec le nouveau propriétaire
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Vérifier que l'animal est toujours à vendre
        final animalDoc = await transaction.get(animalRef);
        if (!animalDoc.exists || animalDoc['isForSale'] != true) {
          throw Exception('Cet animal n\'est plus disponible à la vente');
        }

        // Mettre à jour l'animal avec les nouvelles informations
        transaction.update(animalRef, {
          'ownerId': currentUser.uid,
          'ownerName': '${buyerData['nom']} ${buyerData['prenom']}'.trim(),
          'ownerContact': buyerData['email'],
          'isForSale': false,
          'price': FieldValue.delete(),
        });

        // Créer une notification pour l'ancien propriétaire
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(animalRef.parent.parent?.id)
            .collection('notifications')
            .doc();
            
        transaction.set(notificationRef, {
          'type': 'animal_sold',
          'title': 'Animal vendu',
          'message': '${animalData['nom']} a été acheté par ${buyerData['nom']} ${buyerData['prenom']}',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'animalId': animalRef.id,
        });

        // Créer une notification pour le nouvel acheteur
        final buyerNotificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc();
            
        transaction.set(buyerNotificationRef, {
          'type': 'animal_purchased',
          'title': 'Achat effectué',
          'message': 'Vous avez acheté ${animalData['nom']} pour ${animalData['price']} €',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'animalId': animalRef.id,
        });
      });

      // Afficher un message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Félicitations ! Vous êtes maintenant le propriétaire de ${animalData['nom']}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'achat : $e')),
        );
      }
    }
  }

  Future<void> _navigateToSellScreen(
    BuildContext context,
    DocumentReference animalRef,
    Map<String, dynamic> animalData,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SellAnimalScreen(
          animalId: animalRef.id,
          animalName: animalData['nom'] ?? 'cet animal',
          isForSale: animalData['isForSale'] == true,
          currentPrice: animalData['price']?.toDouble(),
        ),
      ),
    );

    if (result == true && mounted) {
      // Rafraîchir les données si nécessaire
      setState(() {});
    }
  }
}
