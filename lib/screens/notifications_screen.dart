import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'sell_animal_confirmation_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Veuillez vous connecter')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes notifications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune notification'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: isRead ? Colors.white : Colors.blue[50],
                child: ListTile(
                  title: _buildNotificationTitle(data),
                  subtitle: _buildNotificationSubtitle(data),
                  trailing: _buildNotificationTrailing(data),
                  onTap: () => _handleNotificationTap(context, doc.id, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTitle(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'purchase_request':
        return Text('Demande d\'achat pour ${data['animalName']}');
      case 'purchase_confirmed':
        return Text('Achat confirmé: ${data['animalName']}');
      default:
        return const Text('Nouvelle notification');
    }
  }

  Widget _buildNotificationSubtitle(Map<String, dynamic> data) {
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateStr = date != null 
        ? DateFormat('dd/MM/yyyy à HH:mm').format(date)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['type'] == 'purchase_request')
          Text('Acheteur: ${data['buyerEmail']}'),
        if (data['type'] == 'purchase_confirmed')
          Text('Vendu par: ${data['sellerEmail']}'),
        Text(dateStr),
      ],
    );
  }

  Widget? _buildNotificationTrailing(Map<String, dynamic> data) {
    if (data['type'] == 'purchase_request') {
      return Text(
        '${data['price']}€',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    }
    return null;
  }

  void _handleNotificationTap(
    BuildContext context,
    String notificationId,
    Map<String, dynamic> data,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Marquer la notification comme lue
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});

    if (data['type'] == 'purchase_request') {
      // Naviguer vers l'écran de confirmation de vente
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SellAnimalConfirmationScreen(
            notificationId: notificationId,
            animalId: data['animalId'],
            animalName: data['animalName'],
            buyerEmail: data['buyerEmail'],
            price: (data['price'] as num).toDouble(),
          ),
        ),
      );
    }
    // Autres types de notifications...
  }

  @override
  void dispose() {
    super.dispose();
  }
}