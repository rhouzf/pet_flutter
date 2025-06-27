import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:apppet/screens/map_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  double? _currentLatitude;
  double? _currentLongitude;
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activez la localisation dans les paramètres de votre téléphone')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La permission de localisation est nécessaire')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Les permissions de localisation sont définitivement refusées. Activez-les dans les paramètres.')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Position actuelle : ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la récupération de la position : $e')),
      );
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
        title: const Text('Historique des scans'),
        actions: [
          if (_currentLatitude != null && _currentLongitude != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Votre position actuelle:', style: TextStyle(fontSize: 12)),
                  Text(
                    '${_currentLatitude!.toStringAsFixed(5)}, ${_currentLongitude!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _getCurrentLocation,
        tooltip: 'Obtenir ma position',
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.my_location),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('alerts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune alerte reçue pour vos animaux.'));
          }
          final alerts = snapshot.data!.docs;
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final data = alerts[index].data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate();
              final nfc = data['nfcCode'] ?? '-';
              final lat = data['latitude']?.toStringAsFixed(5) ?? '-';
              final lng = data['longitude']?.toStringAsFixed(5) ?? '-';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: Text('Scan de $nfc'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Le ${date != null ? '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : '-'}'),
                      const SizedBox(height: 4),
                      Text('Position: $lat, $lng', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: lat != '-' && lng != '-'
                      ? IconButton(
                          icon: const Icon(Icons.location_on, color: Colors.blue),
                          onPressed: () {
                            // Afficher la position sur la carte
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(
                                  lat: double.parse(lat),
                                  lng: double.parse(lng),
                                ),
                              ),
                            );
                          },
                          tooltip: 'Voir sur la carte',
                        )
                      : const Icon(Icons.location_off, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
