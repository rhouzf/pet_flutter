import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'animal_detail_screen.dart';

class MyAnimalsScreen extends StatefulWidget {
  const MyAnimalsScreen({super.key});

  @override
  State<MyAnimalsScreen> createState() => _MyAnimalsScreenState();
}

class _MyAnimalsScreenState extends State<MyAnimalsScreen> {
  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _checkFirebaseConfig();
  }

  Future<void> _checkFirebaseConfig() async {
    try {
      debugPrint('Vérification de la configuration Firebase...');
      // Essayer d'accéder à une référence de test
      final ref = FirebaseStorage.instance.ref('test-config');
      await ref.getDownloadURL().catchError((error) {
        debugPrint('Erreur de configuration Firebase: $error');
        // C'est normal que cela échoue, on veut juste vérifier la connexion
      });
      debugPrint('Configuration Firebase OK');
    } catch (e) {
      debugPrint('Erreur lors de la vérification de Firebase: $e');
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      _isNfcAvailable = await NfcManager.instance.isAvailable();
      setState(() {});
    } catch (e) {
      _isNfcAvailable = false;
      setState(() {});
    }
  }

  final _user = FirebaseAuth.instance.currentUser;
  final _priceController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _nomController = TextEditingController();
  final _ageController = TextEditingController();
  final _nfcCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isNfcAvailable = false;
  bool _isNfcScanning = false;
  final List<TextEditingController> _vaccinControllers = [];
  final List<String> _vaccins = [];

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text('Utilisateur non connecté.')),
      );
    }
    final userAnimals = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('animals');
    return Scaffold(
      appBar: AppBar(title: const Text('Mes animaux')),
      body: StreamBuilder<QuerySnapshot>(
        stream: userAnimals.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun animal enregistré.'));
          }
          final animals = snapshot.data!.docs;
          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              // Vérifier si le champ isForSale existe, sinon considérer comme false
              final animalData = animal.data() as Map<String, dynamic>?;
              final isForSale = animalData != null && animalData.containsKey('isForSale')
                  ? animalData['isForSale'] == true 
                  : false;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(
                    color: isForSale ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                    width: 1.0,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimalDetailScreen(animal: animal),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Photo de l'animal
                        animal['photoUrl'] != null && animal['photoUrl'] != ''
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  animal['photoUrl'],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.pets, size: 40, color: Colors.grey),
                                  ),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.pets, size: 40, color: Colors.grey),
                              ),
                        const SizedBox(width: 16),
                        
                        // Détails de l'animal
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                animal['nom'] ?? 'Sans nom',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Âge: ${animal['age'] ?? 'Non spécifié'}'),
                              Text('Vaccins: ${animal['vaccins'] ?? 'Non spécifié'}'),
                              if (isForSale && animal['price'] != null)
                                Text(
                                  'À vendre: ${animal['price']} €',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Boutons d'action
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Bouton Supprimer
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmer la suppression'),
                                    content: const Text('Voulez-vous vraiment supprimer cet animal ?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Annuler'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await animal.reference.delete();
                                }
                              },
                            ),
                            
                            // Bouton de vente
                            if (!isForSale)
                              OutlinedButton.icon(
                                onPressed: () => _showSellDialog(
                                  context,
                                  animal.reference,
                                  animal['nom'] ?? 'cet animal',
                                ),
                                icon: const Icon(Icons.sell, size: 16),
                                label: const Text('Mettre en vente'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                  side: const BorderSide(color: Colors.orange),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  // Bouton Vendre à un utilisateur
                                  OutlinedButton.icon(
                                    onPressed: () => _showSellToUserDialog(
                                      context,
                                      animal.reference,
                                      animal['nom'] ?? 'cet animal',
                                    ),
                                    icon: const Icon(Icons.sell, size: 16),
                                    label: const Text('Vendre'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(color: Colors.green),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Bouton Annuler la vente
                                  OutlinedButton.icon(
                                    onPressed: () => _cancelSale(context, animal.reference),
                                    icon: const Icon(Icons.cancel, size: 16),
                                    label: const Text('Annuler'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAnimalDialog(context, userAnimals),
        child: const Icon(Icons.add),
        tooltip: 'Ajouter un animal',
      ),
    );
  }

  void _showAddAnimalDialog(BuildContext context, CollectionReference userAnimals) {
    File? _pickedImage;
    final picker = ImagePicker();
    bool _isLoading = false;
    final _raceController = TextEditingController();
    final _especeController = TextEditingController();
    final _poidsController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _nfcCodeController = TextEditingController();
    final _nomController = TextEditingController();
    final _ageController = TextEditingController();
    final List<TextEditingController> _vaccinControllers = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ajouter un animal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setState(() {
                            _pickedImage = File(picked.path);
                          });
                        }
                      },
                      child: _pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.file(_pickedImage!, width: 100, height: 100, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Icon(Icons.pets, size: 40, color: Colors.grey),
                            ),
                    ),
                    TextField(
                      controller: _nomController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    TextField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: 'Âge'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: _raceController,
                      decoration: const InputDecoration(labelText: 'Race'),
                    ),
                    TextField(
                      controller: _especeController,
                      decoration: const InputDecoration(labelText: 'Espèce'),
                    ),
                    TextField(
                      controller: _poidsController,
                      decoration: const InputDecoration(labelText: 'Poids (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    // Champ pour ajouter un nouveau vaccin
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vaccins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // Liste des vaccins existants
                        ..._vaccinControllers.asMap().entries.map((entry) {
                          int index = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: entry.value,
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
                                      _vaccinControllers[index].dispose();
                                      _vaccinControllers.removeAt(index);
                                      _vaccins.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        // Bouton pour ajouter un nouveau vaccin
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Ajouter un vaccin'),
                          onPressed: () {
                            setState(() {
                              _vaccinControllers.add(TextEditingController());
                              _vaccins.add('');
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nfcCodeController,
                            decoration: InputDecoration(
                              labelText: 'Code NFC (carte animal)',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    _nfcCodeController.text = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
                                  });
                                },
                                tooltip: 'Générer un nouveau code',
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                       IconButton(
                          icon: Icon(Icons.nfc, size: 30, color: _isNfcAvailable ? null : Colors.grey),
                          onPressed: _isNfcAvailable ? () async {
                            final nfcCode = _nfcCodeController.text.trim();
                            if (nfcCode.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Veuillez d\'abord générer un code NFC'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                              return;
                            }

                            try {
                              if (!await NfcManager.instance.isAvailable()) {
                                throw 'NFC non disponible sur cet appareil';
                              }

                              setState(() {
                                _isNfcScanning = true;
                              });

                              // Afficher une boîte de dialogue d'attente
                              if (!mounted) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Prêt à écrire'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Approchez la puce NFC de l\'appareil...'),
                                      ],
                                    ),
                                  );
                                },
                              );

                              bool isWritten = false;
                              
                              await NfcManager.instance.startSession(
                                onDiscovered: (NfcTag tag) async {
                                  try {
                                    final ndef = Ndef.from(tag);
                                    if (ndef == null || !ndef.isWritable) {
                                      throw 'Tag non compatible ou non inscriptible';
                                    }

                                    final message = NdefMessage([
                                      NdefRecord.createText(nfcCode),
                                    ]);

                                    await ndef.write(message);
                                    isWritten = true;
                                    NfcManager.instance.stopSession();
                                    isWritten = true;
                                    
                                    if (mounted) {
                                      Navigator.of(context).pop(); // Fermer la boîte de dialogue
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Écriture sur la puce NFC réussie !'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    NfcManager.instance.stopSession(errorMessage: e.toString());
                                    if (mounted) {
                                      Navigator.of(context).pop(); // Fermer la boîte de dialogue
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erreur: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                },
                                onError: (error) async {
                                  if (mounted) {
                                    Navigator.of(context).pop(); // Fermer la boîte de dialogue
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Erreur NFC: $error'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                },
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('NFC non disponible sur cet appareil'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          tooltip: _isNfcAvailable ? 'Écrire sur une carte NFC' : 'NFC non disponible',
                        ),

                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                if (!_isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                if (!_isLoading)
                  ElevatedButton(
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      String? photoUrl;
                      
                      // Télécharger l'image si elle existe
                      if (_pickedImage != null) {
                        try {
                          setState(() => _isLoading = true);
                          debugPrint('Début du téléchargement de l\'image');
                          
                          // Vérifier si le fichier existe et est accessible
                          debugPrint('Vérification de l\'existence du fichier: ${_pickedImage!.path}');
                          try {
                            final fileInfo = await _pickedImage!.stat();
                            debugPrint('Taille du fichier: ${fileInfo.size} octets');
                            if (fileInfo.size == 0) {
                              throw Exception('Le fichier image est vide');
                            }
                          } catch (e) {
                            debugPrint('Erreur d\'accès au fichier: $e');
                            rethrow;
                          }
                          
                          // Créer un nom de fichier simple
                          final timestamp = DateTime.now().millisecondsSinceEpoch;
                          final fileName = '$timestamp.jpg';
                          debugPrint('Nom du fichier généré: $fileName');
                          
                          // Référence au stockage dans le dossier de l'utilisateur
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            debugPrint('Erreur: Aucun utilisateur connecté');
                            throw Exception('Utilisateur non connecté');
                          }
                          
                          final storagePath = 'animals/${user.uid}/$fileName';
                          debugPrint('Chemin de stockage: $storagePath');
                          
                          final storageRef = FirebaseStorage.instance.ref(storagePath);
                          debugPrint('Référence de stockage créée');
                          
                          // Télécharger le fichier avec des métadonnées de base
                          try {
                            debugPrint('Début du téléchargement vers Firebase Storage');
                            
                            // Vérifier la connectivité
                            try {
                              await FirebaseStorage.instance.ref().child('test').getDownloadURL();
                            } catch (e) {
                              debugPrint('Erreur de connexion à Firebase Storage: $e');
                              throw Exception('Impossible de se connecter à Firebase Storage. Vérifiez votre connexion Internet.');
                            }
                            
                            final metadata = SettableMetadata(
                              contentType: 'image/jpeg',
                              cacheControl: 'public, max-age=31536000',
                            );
                            
                            debugPrint('Tentative de téléversement du fichier...');
                            final uploadTask = storageRef.putFile(_pickedImage!, metadata);
                            
                            // Suivre la progression
                            uploadTask.snapshotEvents.listen((taskSnapshot) {
                              debugPrint('Progression: ${taskSnapshot.bytesTransferred}/${taskSnapshot.totalBytes}');
                            }, onError: (error) {
                              debugPrint('Erreur lors du suivi de la progression: $error');
                            });
                            
                            // Attendre la fin du téléchargement
                            debugPrint('En attente de la fin du téléchargement...');
                            final snapshot = await uploadTask;
                            
                            if (snapshot.state == TaskState.success) {
                              debugPrint('Téléversement réussi, obtention de l\'URL...');
                              try {
                                photoUrl = await storageRef.getDownloadURL();
                                debugPrint('URL de téléchargement obtenue avec succès: $photoUrl');
                              } catch (urlError) {
                                debugPrint('Erreur lors de l\'obtention de l\'URL: $urlError');
                                throw Exception('Impossible d\'obtenir l\'URL de l\'image téléchargée');
                              }
                            } else {
                              throw Exception('Échec du téléchargement de l\'image (${snapshot.state})');
                            }
                          } catch (uploadError) {
                            debugPrint('Erreur lors du téléversement: $uploadError');
                            // Essayer de supprimer le fichier partiellement téléchargé
                            try {
                              await storageRef.delete();
                            } catch (deleteError) {
                              debugPrint('Erreur lors du nettoyage: $deleteError');
                            }
                            rethrow;
                          }
                          
                        } catch (e) {
                          debugPrint('Erreur de téléchargement: $e');
                          setState(() => _isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                          return;
                        }
                      }
                      
                      final nfcCode = _nfcCodeController.text.trim().toLowerCase();
                      final existing = await FirebaseFirestore.instance
                          .collectionGroup('animals')
                          .where('nfcCode', isEqualTo: nfcCode)
                          .limit(1)
                          .get();
                      if (existing.docs.isNotEmpty) {
                        setState(() => _isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ce code NFC est déjà utilisé pour un autre animal.')),
                          );
                        }
                        return;
                      }
                      Position? position;
                      try {
                        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                        if (!serviceEnabled) {
                          throw Exception("Activez la localisation sur votre appareil.");
                        }
                        LocationPermission permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          permission = await Geolocator.requestPermission();
                          if (permission == LocationPermission.denied) {
                            throw Exception("Permission de localisation refusée.");
                          }
                        }
                        if (permission == LocationPermission.deniedForever) {
                          throw Exception("Permission de localisation refusée définitivement.");
                        }
                        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                      } catch (e) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur GPS : '+e.toString())),
                        );
                        return;
                      }

try {
                        // Vérifier si une image est sélectionnée mais n'a pas pu être téléchargée
                        if (_pickedImage != null && (photoUrl == null || photoUrl.isEmpty)) {
                          throw Exception('Erreur lors du téléchargement de l\'image');
                        }

                        await userAnimals.add({
                          'nom': _nomController.text.trim(),
                          'age': _ageController.text.trim(),
                          'race': _raceController.text.trim(),
                          'espece': _especeController.text.trim(),
                          'poids': _poidsController.text.trim(),
                          'description': _descriptionController.text.trim(),
                          'vaccins': _vaccinControllers
                              .map((controller) => controller.text.trim())
                              .where((vaccin) => vaccin.isNotEmpty)
                              .toList(),
                          'nfcCode': nfcCode,
                          'latitude': position?.latitude,
                          'longitude': position?.longitude,
                          'photoUrl': photoUrl ?? '',
                          'imageUrl': photoUrl,
                          'isForSale': false,
                          'price': null,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        
                        // Nettoyer les contrôleurs après l'ajout réussi
                        _nomController.clear();
                        _ageController.clear();
                        _raceController.clear();
                        _especeController.clear();
                        _poidsController.clear();
                        _descriptionController.clear();
                        _nfcCodeController.clear();
                        for (var controller in _vaccinControllers) {
                          controller.dispose();
                        }
                        _vaccinControllers.clear();
                        _pickedImage = null;
                      } catch (e) {
                        setState(() => _isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur lors de l\'ajout de l\'animal: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      setState(() => _isLoading = false);
                      Navigator.pop(context);
                    },
                    child: const Text('Ajouter'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _writeNfcTag(BuildContext context, TextEditingController nfcController, StateSetter setState) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC non disponible sur cet appareil.')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Écriture NFC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Approchez la carte NFC de l\'appareil...'),
            const SizedBox(height: 8),
            Text(
              'Code à écrire: ${nfcController.text.isNotEmpty ? nfcController.text : 'Générer d\'abord un code' }',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) throw Exception('Le tag ne supporte pas NDEF');

            if (nfcController.text.isEmpty) {
              final newCode = DateTime.now().millisecondsSinceEpoch.toString();
              nfcController.text = newCode;
              setState(() {});
            }

            final message = NdefMessage([
              NdefRecord.createText(nfcController.text),
            ]);

            await ndef.write(message);

            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Écriture réussie sur la carte NFC')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur d\'écriture: $e')),
              );
            }
          } finally {
            await NfcManager.instance.stopSession();
          }
        },
        onError: (e) async {
          if (context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors de la communication NFC')),
            );
          }
          await NfcManager.instance.stopSession();
          return;
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'initialisation NFC')),
        );
      }
    }
  }


  // Affiche la boîte de dialogue pour mettre en vente un animal
  Future<void> _showSellDialog(
    BuildContext context,
    DocumentReference animalRef,
    String animalName,
  ) async {
    _priceController.clear();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mettre $animalName en vente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Définissez un prix de vente pour votre animal :'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prix (€)',
                  border: OutlineInputBorder(),
                  prefixText: '€ ',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(_priceController.text);
              if (price != null && price > 0) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un prix valide'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        setState(() => _isLoading = true);
        final price = double.parse(_priceController.text);
        
        await animalRef.update({
          'isForSale': true,
          'price': price,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$animalName est maintenant en vente pour $price €'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la mise en vente : $e'),
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

  // Affiche la boîte de dialogue pour vendre un animal à un utilisateur spécifique
  Future<void> _showSellToUserDialog(
    BuildContext context,
    DocumentReference animalRef,
    String animalName,
  ) async {
    _buyerEmailController.clear();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vendre $animalName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Entrez l\'email de l\'acheteur :'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buyerEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email de l\'acheteur',
                  border: OutlineInputBorder(),
                  hintText: 'exemple@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = _buyerEmailController.text.trim();
              if (email.isNotEmpty && email.contains('@') && email.contains('.')) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un email valide'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _sellAnimalToUser(
        context, 
        animalRef, 
        animalName, 
        _buyerEmailController.text.trim()
      );
    }
  }

  // Vendre un animal à un utilisateur spécifique
  Future<void> _sellAnimalToUser(
    BuildContext context,
    DocumentReference animalRef,
    String animalName,
    String buyerEmail,
  ) async {
    try {
      setState(() => _isLoading = true);
      
      // Vérifier d'abord si l'utilisateur existe
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: buyerEmail)
          .limit(1)
          .get();

      if (usersSnapshot.docs.isEmpty) {
        throw 'Aucun utilisateur trouvé avec cet email';
      }

      final buyerData = usersSnapshot.docs.first.data();
      final buyerId = usersSnapshot.docs.first.id;
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        throw 'Utilisateur non connecté';
      }

      // Récupérer les données actuelles de l'animal
      final animalDoc = await animalRef.get();
      if (!animalDoc.exists) {
        throw 'Animal introuvable';
      }

      final animalData = animalDoc.data() as Map<String, dynamic>;
      
      // Vérifier que l'animal est bien à vendre
      if (animalData['isForSale'] != true) {
        throw 'Cet animal n\'est plus à vendre';
      }

      // Vérifier que l'utilisateur ne s'achète pas son propre animal
      if (buyerId == currentUser.uid) {
        throw 'Vous ne pouvez pas vous vendre votre propre animal';
      }

      // Créer une transaction pour assurer l'intégrité des données
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Vérifier que l'animal est toujours à vendre
        final freshAnimal = await transaction.get(animalRef);
        if (!freshAnimal.exists || freshAnimal['isForSale'] != true) {
          throw 'Cet animal n\'est plus disponible à la vente';
        }

        // Créer une copie de l'animal dans la collection de l'acheteur
        final buyerAnimalsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(buyerId)
            .collection('animals')
            .doc();

        // Préparer les données de l'animal pour le nouvel utilisateur
        final newAnimalData = Map<String, dynamic>.from(animalData);
        // Définir explicitement isForSale à false pour le nouvel utilisateur
        newAnimalData['isForSale'] = false;
        newAnimalData.remove('price'); // Supprimer le prix de vente précédent
        newAnimalData['previousOwnerId'] = currentUser.uid;
        newAnimalData['purchaseDate'] = FieldValue.serverTimestamp();
        newAnimalData['updatedAt'] = FieldValue.serverTimestamp();

        // Ajouter l'animal à la collection de l'acheteur
        transaction.set(buyerAnimalsRef, newAnimalData);

        // Supprimer l'animal de la collection du vendeur
        transaction.delete(animalRef);

        // Créer une notification pour l'acheteur
        final buyerNotificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(buyerId)
            .collection('notifications')
            .doc();

        transaction.set(buyerNotificationRef, {
          'type': 'animal_purchased',
          'title': 'Nouvel animal acheté',
          'message': 'Vous avez acheté $animalName',
          'animalId': buyerAnimalsRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        // Créer une notification pour le vendeur
        final sellerNotificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc();

        transaction.set(sellerNotificationRef, {
          'type': 'animal_sold',
          'title': 'Animal vendu',
          'message': 'Vous avez vendu $animalName à ${buyerData['email']}',
          'animalId': buyerAnimalsRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      });

      if (mounted) {
        // Fermer la boîte de dialogue avant d'afficher le SnackBar
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        // Utiliser le ScaffoldMessenger avec un nouveau contexte
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$animalName a été vendu à $buyerEmail avec succès'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Utiliser le ScaffoldMessenger avec un nouveau contexte
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors de la vente : $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Annule la mise en vente d'un animal
  Future<void> _cancelSale(BuildContext context, DocumentReference animalRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la vente'),
        content: const Text('Voulez-vous vraiment annuler la mise en vente de cet animal ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        
        await animalRef.update({
          'isForSale': false,
          'price': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La mise en vente a été annulée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'annulation : $e'),
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

  @override
  void dispose() {
    _priceController.dispose();
    _buyerEmailController.dispose();
    _nomController.dispose();
    _ageController.dispose();
    for (var controller in _vaccinControllers) {
      controller.dispose();
    }
    _nfcCodeController.dispose();
    super.dispose();
  }
}
