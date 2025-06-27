import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _cinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _register(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'nom': _nomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'cin': _cinController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Prépare la sous-collection 'animals' (optionnel, Firestore la crée à l'ajout d'un animal)
      }
      Navigator.pushReplacementNamed(
        context,
        '/my_animals',
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanCIN() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    final inputImage = InputImage.fromFilePath(pickedFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    String text = recognizedText.text;

    RegExp nomReg = RegExp(r'Nom\s*:\s*(\w+)');
    RegExp prenomReg = RegExp(r'Prénom\s*:\s*(\w+)');
    RegExp cinReg = RegExp(r'(CIN|N°|Numéro)\s*:?\s*([A-Z0-9]+)');

    String nom = nomReg.firstMatch(text)?.group(1) ?? '';
    String prenom = prenomReg.firstMatch(text)?.group(1) ?? '';
    String cin = cinReg.firstMatch(text)?.group(2) ?? '';

    setState(() {
      _nomController.text = nom;
      _prenomController.text = prenom;
      _cinController.text = cin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')), 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scanner ma carte'),
                  onPressed: _scanCIN,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _prenomController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cinController,
                  decoration: const InputDecoration(labelText: 'CIN'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: () => _register(context),
                    child: const Text('Créer mon compte'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _cinController.dispose();
    super.dispose();
  }
}
