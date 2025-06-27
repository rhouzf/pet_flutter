import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class MapScreen extends StatefulWidget {
  final double? lat;
  final double? lng;
  const MapScreen({Key? key, this.lat, this.lng}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _position;
  final List<Marker> _markers = [];
  bool _loading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _initMap() {
    try {
      if (widget.lat != null && widget.lng != null) {
        _position = LatLng(widget.lat!, widget.lng!);
        _markers.clear();
        _markers.add(
          Marker(
            width: 40.0,
            height: 40.0,
            point: _position!,
            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
          ),
        );
      }
      _loading = false;
    } catch (e) {
      print('Erreur d\'initialisation de la carte: $e');
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localisation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _position ?? const LatLng(33.5731, -7.5898),
                    zoom: _position != null ? 15.0 : 7.0,
                    onTap: (tapPosition, point) {
                      // Gérer les clics sur la carte si nécessaire
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.apppet',
                    ),
                    MarkerLayer(
                      markers: _markers,
                    ),
                  ],
                ),
                if (_position == null)
                  const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Position non disponible'),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: () {
                      if (_position != null) {
                        _mapController.move(_position!, 15);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
    );
  }
}
