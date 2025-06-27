import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  bool _isScanning = false;
  String? _error;
  String? _lastNfcCode;

  Future<void> _startNfcScan() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isScanning = false;
        _error = "NFC non disponible sur cet appareil.";
      });
      return;
    }

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          NfcManager.instance.stopSession();
          String? nfcText;
          try {
            final ndef = Ndef.from(tag);
            if (ndef != null && ndef.cachedMessage != null) {
              final payload = ndef.cachedMessage!.records.first.payload;
              print('Payload hex: ${payload.map((e) => e.toRadixString(16)).toList()}');
              final langCodeLen = payload.first & 0x3F;
              nfcText = String.fromCharCodes(payload.skip(1 + langCodeLen)).trim();
              print('Code NFC nettoyé : "$nfcText"');
              setState(() {
                _lastNfcCode = nfcText;
              });
              // Navigation automatique vers DetailsScreen
              if (mounted && nfcText.isNotEmpty) {
                // Récupérer la position GPS
                Position? position;
                try {
                  position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                } catch (e) {
                  print('Erreur Geolocator: $e');
                  position = null;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Localisation indisponible : activez le GPS et autorisez l\'application.')),
                    );
                  }
                }

                if (position == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Impossible de récupérer la position GPS.')),
                    );
                  }
                }

                // Chercher l'animal pour retrouver le propriétaire
                final animalSnap = await FirebaseFirestore.instance
                  .collectionGroup('animals')
                  .where('nfcCode', isEqualTo: nfcText.trim().toLowerCase())
                  .limit(1)
                  .get();
                String? ownerId;
                if (animalSnap.docs.isNotEmpty) {
                  final animalDoc = animalSnap.docs.first;
                  // parent.parent = document user
                  ownerId = animalDoc.reference.parent.parent?.id;
                }

                // Enregistrer l'alerte dans la sous-collection du propriétaire
                if (ownerId != null) {
                  await FirebaseFirestore.instance
                    .collection('users')
                    .doc(ownerId)
                    .collection('alerts')
                    .add({
                      'nfcCode': nfcText.trim().toLowerCase(),
                      'timestamp': FieldValue.serverTimestamp(),
                      'latitude': position?.latitude,
                      'longitude': position?.longitude,
                      'animalId': animalSnap.docs.first.id,
                    });
                }

                Navigator.pushReplacementNamed(
                  context,
                  '/details',
                  arguments: {
                    'nfcText': nfcText,
                  },
                );
              }
            }
          } catch (e) {
            setState(() {
              _error = "Erreur de décodage du tag.";
            });
          }
        },
        onError: (e) async {
          setState(() {
            _isScanning = false;
            _error = "Erreur lors de la lecture NFC.";
          });
          NfcManager.instance.stopSession(errorMessage: 'Erreur NFC');
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _error = "Erreur lors de l'initialisation de la session NFC.";
      });
    }
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lecture NFC')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Approchez la puce NFC de l\'appareil'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startNfcScan,
              child: const Text("Démarrer la lecture"),
            ),
            const SizedBox(height: 16),
            if (_lastNfcCode != null)
              Text('Code NFC lu : $_lastNfcCode', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
