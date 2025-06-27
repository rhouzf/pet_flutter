import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellAnimalScreen extends StatefulWidget {
  final String animalId;
  final String animalName;
  final bool isForSale;
  final double? currentPrice;

  const SellAnimalScreen({
    Key? key,
    required this.animalId,
    required this.animalName,
    this.isForSale = false,
    this.currentPrice,
  }) : super(key: key);

  @override
  _SellAnimalScreenState createState() => _SellAnimalScreenState();
}

class _SellAnimalScreenState extends State<SellAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  bool _isForSale = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isForSale = widget.isForSale;
    if (widget.currentPrice != null) {
      _priceController.text = widget.currentPrice!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _updateSaleStatus() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final animalRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('animals')
          .doc(widget.animalId);

      final updateData = <String, dynamic>{
        'isForSale': _isForSale,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isForSale) {
        // Récupérer les informations de l'utilisateur actuel
        final user = FirebaseAuth.instance.currentUser!;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        updateData.addAll({
          'price': double.parse(_priceController.text),
          'userId': user.uid,  // Stocker l'ID du propriétaire
          'ownerEmail': user.email ?? userDoc.data()?['email'] ?? '',  // Email du propriétaire
          'ownerName': user.displayName ?? userDoc.data()?['name'] ?? '',  // Nom du propriétaire
        });
      } else {
        // Si on retire de la vente, on supprime aussi les champs liés à la vente
        updateData.addAll({
          'price': FieldValue.delete(),
          'userId': FieldValue.delete(),
          'ownerEmail': FieldValue.delete(),
          'ownerName': FieldValue.delete(),
        });
      }

      await animalRef.update(updateData);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isForSale ? 'Vendre ${widget.animalName}' : 'Mettre en vente ${widget.animalName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: const Text('Mettre en vente'),
                value: _isForSale,
                onChanged: (value) {
                  setState(() {
                    _isForSale = value;
                  });
                },
              ),
              if (_isForSale) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Prix (€)',
                    border: OutlineInputBorder(),
                    prefixText: '€ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un prix';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Veuillez entrer un prix valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Les autres utilisateurs pourront voir et acheter votre animal à ce prix.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateSaleStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isForSale ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isForSale ? 'Mettre en vente' : 'Retirer de la vente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
