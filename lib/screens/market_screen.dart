import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _forceRefresh() async {
    setState(() {});
    debugPrint('=== FORÇAGE DU RECHARGEMENT ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marché des animaux'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefresh,
            tooltip: 'Rafraîchir et afficher les logs de débogage',
          ),
        ],
      ),
      body: _buildAnimalList(),
    );
  }

  Widget _buildAnimalList() {
    final stream = _firestore
        .collectionGroup('animals')
        .where('isForSale', isEqualTo: true)
        .snapshots();

    // Log pour déboguer la requête
    stream.listen(
      (querySnapshot) {
        debugPrint('=== DÉBUT LOGS DÉBOGAGE ===');
        debugPrint('Nouvelle mise à jour de la requête:');
        debugPrint('Chemin de la collection: users/{userId}/animals');
        debugPrint('Nombre de documents: ${querySnapshot.docs.length}');
        
        if (querySnapshot.docs.isEmpty) {
          debugPrint('AUCUN ANIMAL TROUVÉ - Vérifiez que:');
          debugPrint('1. Des animaux sont marqués comme isForSale: true');
          debugPrint('2. Les règles Firestore autorisent la lecture de ces documents');
        }
        
        for (var doc in querySnapshot.docs) {
          debugPrint('\n--- Document ID: ${doc.id} ---');
          debugPrint('Chemin complet: ${doc.reference.path}');
          debugPrint('Données: ${doc.data()}');
          
          // Vérifier les champs importants
          final data = doc.data() as Map<String, dynamic>;
          debugPrint('isForSale: ${data['isForSale']}');
          debugPrint('Prix: ${data['price']}');
          debugPrint('Nom: ${data['nom']}');
        }
        debugPrint('=== FIN LOGS DÉBOGAGE ===\n');
      },
      onError: (error) {
        debugPrint('=== ERREUR DE REQUÊTE ===');
        debugPrint('Erreur: $error');
        debugPrint('Vérifiez les règles Firestore et la connexion internet');
        debugPrint('=========================');
      },
    );

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun animal en vente pour le moment'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final animalDoc = snapshot.data!.docs[index];
            final animalData = animalDoc.data() as Map<String, dynamic>;
            final isCurrentUser = animalDoc.reference.parent.parent?.id == _auth.currentUser?.uid;

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: (animalData['photoUrl'] != null && animalData['photoUrl'].toString().isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          animalData['photoUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.pets, size: 30, color: Colors.grey),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.pets, size: 30, color: Colors.grey),
                      ),
                title: Text(animalData['nom'] ?? 'Sans nom'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (animalData['race'] != null) Text('Race: ${animalData['race']}'),
                    if (animalData['age'] != null) Text('Âge: ${animalData['age']}'),
                    Text('Prix: ${animalData['price']} €'),
                    if (animalData['ownerName'] != null)
                      Text('Vendeur: ${animalData['ownerName']}'),
                  ],
                ),
                trailing: isCurrentUser
                    ? const Text('Votre annonce')
                    : ElevatedButton(
                        onPressed: () => _showBuyDialog(context, animalDoc.reference, animalData),
                        child: const Text('Acheter'),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  final _buyerEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _buyerEmailController.dispose();
    super.dispose();
  }

  Future<void> _showBuyDialog(
    BuildContext context,
    DocumentReference animalRef,
    Map<String, dynamic> animalData,
  ) async {
    if (!mounted) return;
    
    final currentUser = _auth.currentUser;
    final animalName = animalData['nom'] ?? 'cet animal';
    final animalPrice = animalData['price'] is num 
        ? '${animalData['price']}€' 
        : 'un prix inconnu';

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez vous connecter pour effectuer un achat')),
        );
      }
      return;
    }

    // Vérifier si l'utilisateur essaie d'acheter son propre animal
    final sellerId = animalRef.parent.parent?.id;
    if (sellerId == currentUser.uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous ne pouvez pas acheter votre propre animal')),
        );
      }
      return;
    }

    // Demander l'email de l'acheteur
    final buyerEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'achat'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vous souhaitez acheter $animalName pour $animalPrice.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _buyerEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Votre email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Veuillez entrer un email valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Le vendeur sera notifié et vous contactera pour finaliser la vente.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.validate() == true) {
                Navigator.of(context).pop(_buyerEmailController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer la demande'),
          ),
        ],
      ),
    );

    if (buyerEmail == null) return; // L'utilisateur a annulé

    if (buyerEmail.isNotEmpty) {
      await _buyAnimal(
        animalRef, 
        animalData,
        buyerEmail: buyerEmail,
      );
    }
  }

  Future<void> _buyAnimal(
    DocumentReference animalRef,
    Map<String, dynamic> animalData, {
    required String buyerEmail,
  }) async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);
    final currentUser = _auth.currentUser;
    final animalName = animalData['nom'] ?? 'cet animal';
    
    // Fonction utilitaire pour afficher les erreurs
    void showError(String message) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    if (currentUser == null) {
      showError('Veuillez vous connecter pour effectuer un achat');
      return;
    }

    try {
      // Vérifier que l'animal est toujours à vendre
      final getOptions = GetOptions(source: Source.server);
      final animalDoc = await animalRef.get(getOptions);
      
      if (!animalDoc.exists) {
        throw 'Cet animal n\'existe plus';
      }
      
      final docData = animalDoc.data() as Map<String, dynamic>?;
      if (docData == null) {
        throw 'Impossible de récupérer les informations de l\'animal';
      }
      
      if (docData['isForSale'] != true) {
        throw 'Cet animal n\'est plus disponible à la vente';
      }

      // Récupérer les informations du vendeur
      final sellerId = animalData['userId']?.toString() ?? animalRef.parent.parent?.id;
      debugPrint('=== DÉBOGAGE VENDEUR ===');
      debugPrint('ID du vendeur: $sellerId');
      debugPrint('Chemin du document animal: ${animalRef.path}');
      
      if (sellerId == null) {
        debugPrint('ERREUR: Impossible de déterminer l\'ID du vendeur');
        throw 'Impossible de déterminer le vendeur';
      }
      
      // Vérifier que l'acheteur n'est pas le vendeur
      if (sellerId == currentUser.uid) {
        throw 'Vous ne pouvez pas acheter votre propre animal';
      }

      // Essayer de récupérer l'email du vendeur directement depuis les données de l'animal
      String? sellerEmail = animalData['ownerEmail']?.toString().trim();
      
      // Si l'email n'est pas dans les données de l'animal, essayer de le récupérer depuis le profil utilisateur
      if (sellerEmail == null || sellerEmail.isEmpty) {
        debugPrint('Email du vendeur non trouvé dans les données de l\'animal, recherche dans users...');
        
        try {
          final sellerDoc = await _firestore.collection('users').doc(sellerId).get();
          debugPrint('Document vendeur existe: ${sellerDoc.exists}');
          
          if (!sellerDoc.exists) {
            debugPrint('ERREUR: Document vendeur non trouvé dans la collection users');
            // Essayer de trouver l'utilisateur par son ID dans la collection users
            final userQuery = await _firestore
                .collection('users')
                .where(FieldPath.documentId, isEqualTo: sellerId)
                .limit(1)
                .get();
                
            if (userQuery.docs.isEmpty) {
              throw 'Impossible de contacter le vendeur (compte introuvable)';
            }
            
            final sellerData = userQuery.docs.first.data();
            sellerEmail = sellerData['email']?.toString().trim();
          } else {
            final sellerData = sellerDoc.data();
            sellerEmail = sellerData?['email']?.toString().trim();
          }
          
          debugPrint('Données vendeur: ${sellerDoc.data()}');
        } catch (e) {
          debugPrint('Erreur lors de la récupération du vendeur: $e');
          rethrow;
        }
      }
      
      debugPrint('Email vendeur: $sellerEmail');
      
      if (sellerEmail == null || sellerEmail.isEmpty) {
        debugPrint('ERREUR: Email vendeur manquant ou vide');
        throw 'Impossible de contacter le vendeur (email manquant)';
      }

      // Créer une notification pour le vendeur
      await _firestore.collection('users').doc(sellerId).collection('notifications').add({
        'type': 'purchase_request',
        'animalId': animalRef.id,
        'animalName': animalName,
        'animalData': animalData, // Stocker toutes les données de l'animal
        'animalRef': animalRef.path, // Référence complète vers l'animal
        'buyerId': currentUser.uid,
        'buyerEmail': buyerEmail,
        'price': animalData['price'],
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'en_attente', // Statut de la demande
      });

      // Envoyer un email au vendeur (à implémenter avec votre solution d'envoi d'email)
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande d\'achat envoyée au vendeur !'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Fermer le dialogue d'achat
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'achat : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
