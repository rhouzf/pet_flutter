import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellAnimalConfirmationScreen extends StatefulWidget {
  final String notificationId;
  final String animalId;
  final String animalName;
  final String buyerEmail;
  final double price;

  const SellAnimalConfirmationScreen({
    Key? key,
    required this.notificationId,
    required this.animalId,
    required this.animalName,
    required this.buyerEmail,
    required this.price,
  }) : super(key: key);

  @override
  _SellAnimalConfirmationScreenState createState() => _SellAnimalConfirmationScreenState();
}

class _SellAnimalConfirmationScreenState extends State<SellAnimalConfirmationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  final _buyerEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _buyerEmailController.text = widget.buyerEmail;
  }

  @override
  void dispose() {
    _buyerEmailController.dispose();
    super.dispose();
  }

  Future<void> _confirmSale() async {
    if (_isLoading || !mounted) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'Veuillez vous connecter pour confirmer la vente';
      }

      // Récupérer les informations complètes de la notification
      final notificationDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .doc(widget.notificationId)
          .get();

      if (!notificationDoc.exists) {
        throw 'Notification introuvable';
      }

      final notificationData = notificationDoc.data();
      if (notificationData == null) {
        throw 'Données de notification invalides';
      }

      final buyerId = notificationData['buyerId'] as String?;
      final buyerEmail = notificationData['buyerEmail'] as String?;
      final animalRefPath = notificationData['animalRef'] as String?;
      final animalDataFromNotif = notificationData['animalData'] as Map<String, dynamic>?;

      if (buyerId == null || buyerEmail == null || animalRefPath == null || animalDataFromNotif == null) {
        throw 'Données de vente incomplètes';
      }

      final sellerId = currentUser.uid;

      // Vérifier que l'animal existe toujours et appartient bien au vendeur
      final animalDoc = await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('animals')
          .doc(widget.animalId)
          .get();

      if (!animalDoc.exists) {
        throw 'Animal introuvable';
      }

      final animalData = animalDoc.data();
      if (animalData == null || animalData['isForSale'] != true) {
        throw 'Cet animal n\'est plus à vendre';
      }

      // Démarrer une transaction
      await _firestore.runTransaction((transaction) async {
        // 1. Supprimer l'animal du vendeur
        transaction.delete(animalDoc.reference);

        // 2. Ajouter l'animal à la collection de l'acheteur
        final newAnimalRef = _firestore
            .collection('users')
            .doc(buyerId)
            .collection('animals')
            .doc();

        // Mettre à jour les données de l'animal
        final updatedData = Map<String, dynamic>.from(animalData);
        updatedData['isForSale'] = false;
        updatedData['previousOwnerId'] = sellerId;
        updatedData['saleDate'] = FieldValue.serverTimestamp();

        transaction.set(newAnimalRef, updatedData);

        // 3. Créer une notification pour l'acheteur
        final buyerNotificationRef = _firestore
            .collection('users')
            .doc(buyerId)
            .collection('notifications')
            .doc();

        transaction.set(buyerNotificationRef, {
          'type': 'purchase_confirmed',
          'animalId': widget.animalId,
          'animalName': widget.animalName,
          'sellerEmail': currentUser.email,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      });

      // Mettre à jour la notification avec le statut 'terminé' et la marquer comme lue
      await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('notifications')
          .doc(widget.notificationId)
          .update({
            'read': true,
            'status': 'terminé',
            'completedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vente confirmée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmer la vente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirmer la vente de ${widget.animalName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Prix: ${widget.price}€',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _buyerEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email de l\'acheteur',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'En confirmant, vous transférerez la propriété de l\'animal à l\'acheteur.',
                style: TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Confirmer la vente',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}