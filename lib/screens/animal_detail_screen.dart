import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnimalDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot animal;
  const AnimalDetailScreen({required this.animal, Key? key}) : super(key: key);

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  late TextEditingController _nomController;
  late TextEditingController _ageController;
  late TextEditingController _nfcCodeController;
  late TextEditingController _raceController;
  late TextEditingController _especeController;
  late TextEditingController _poidsController;
  late TextEditingController _descriptionController;
  late List<String> _vaccins;
  bool _isLoading = false;
  bool _isNfcAvailable = false;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.animal['nom'] ?? '');
    _ageController = TextEditingController(text: widget.animal['age']?.toString() ?? '');
    _nfcCodeController = TextEditingController(text: widget.animal['nfcCode'] ?? '');
    _raceController = TextEditingController(text: widget.animal['race'] ?? '');
    _especeController = TextEditingController(text: widget.animal['espece'] ?? '');
    _poidsController = TextEditingController(text: widget.animal['poids']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.animal['description'] ?? '');
    _vaccins = List<String>.from(widget.animal['vaccins'] ?? []);
    // Utiliser photoUrl comme fallback si imageUrl n'existe pas
    _imageUrl = widget.animal['imageUrl'] ?? widget.animal['photoUrl'] ?? '';
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _ageController.dispose();
    _nfcCodeController.dispose();
    _raceController.dispose();
    _especeController.dispose();
    _poidsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return _imageUrl;
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('animals')
          .child('${_userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await storageRef.putFile(_image!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du téléchargement de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Widget _buildVaccinsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vaccins', style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 8),
        ..._vaccins.asMap().entries.map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _vaccins[index],
                    onChanged: (value) {
                      _vaccins[index] = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'Vaccin ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _vaccins.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),
        TextButton.icon(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Ajouter un vaccin'),
          onPressed: () {
            setState(() {
              _vaccins.add('');
            });
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  )
                : _imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(_imageUrl!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Ajouter une photo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Appuyez pour changer la photo',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de l\'animal'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveAnimal,
              tooltip: 'Enregistrer les modifications',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildImagePicker(),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _especeController,
                    decoration: const InputDecoration(
                      labelText: 'Espèce',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _raceController,
                    decoration: const InputDecoration(
                      labelText: 'Race',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Âge',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                      suffixText: 'ans',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _poidsController,
                    decoration: const InputDecoration(
                      labelText: 'Poids',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight),
                      suffixText: 'kg',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nfcCodeController,
              decoration: const InputDecoration(
                labelText: 'Code NFC',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.nfc),
                hintText: 'Code NFC de l\'animal',
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Ajoutez une description ou des notes...',
                alignLabelWithHint: true,
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 24),
            _buildVaccinsInput(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Supprimer cet animal'),
                          content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cet animal ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _deleteAnimal();
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                    },
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Supprimer l\'animal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAnimal() async {
    if (_nomController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le nom est requis'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Télécharger la nouvelle image si nécessaire
      String? newImageUrl = await _uploadImage();
      
      // Mettre à jour les données dans Firestore
      await widget.animal.reference.update({
        'nom': _nomController.text.trim(),
        'age': _ageController.text.trim(),
        'race': _raceController.text.trim(),
        'espece': _especeController.text.trim(),
        'poids': double.tryParse(_poidsController.text) ?? 0.0,
        'description': _descriptionController.text.trim(),
        'nfcCode': _nfcCodeController.text.trim(),
        'vaccins': _vaccins.where((v) => v.isNotEmpty).toList(),
        if (newImageUrl != null) 'imageUrl': newImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Animal mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
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

  Future<void> _deleteAnimal() async {
    setState(() => _isLoading = true);

    try {
      await widget.animal.reference.delete();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
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
