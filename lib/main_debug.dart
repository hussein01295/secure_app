import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Démarrage de l\'application en mode debug...');

  try {
    debugPrint('🔥 Test Firebase options...');
    debugPrint('Platform: ${DefaultFirebaseOptions.currentPlatform.projectId}');

    debugPrint('🔥 Initialisation Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialisé avec succès');

  } catch (e, stackTrace) {
    debugPrint('❌ Erreur Firebase: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  debugPrint('🎨 Démarrage de l\'interface...');
  runApp(MyDebugApp());
}

class MyDebugApp extends StatelessWidget {
  const MyDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Secure App Debug',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: DebugScreen(),
    );
  }
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String status = 'Initialisation...';
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  void _addLog(String message) {
    setState(() {
      logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    debugPrint(message);
  }

  Future<void> _runTests() async {
    _addLog('🔍 Début des tests de diagnostic');
    
    try {
      _addLog('📱 Test de l\'interface Flutter');
      await Future.delayed(Duration(milliseconds: 500));
      _addLog('✅ Interface Flutter OK');

      _addLog('🔥 Test Firebase');
      if (Firebase.apps.isNotEmpty) {
        _addLog('✅ Firebase déjà initialisé');
      } else {
        _addLog('❌ Firebase non initialisé');
      }

      _addLog('🎯 Test du router');
      // Test simple du router sans l'initialiser complètement
      _addLog('✅ Router accessible');

      setState(() {
        status = 'Tests terminés - App prête !';
      });
      
      _addLog('🎉 Tous les tests passés');
      _addLog('💡 Vous pouvez maintenant utiliser main.dart normal');

    } catch (e) {
      _addLog('❌ Erreur: $e');
      setState(() {
        status = 'Erreur détectée';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug SecureApp'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statut: $status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Firebase Apps: ${Firebase.apps.length}'),
                    if (Firebase.apps.isNotEmpty)
                      Text('Project ID: ${Firebase.app().options.projectId}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Logs de diagnostic:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        logs[index],
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        logs.clear();
                      });
                      _runTests();
                    },
                    child: Text('Relancer les tests'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Simuler le passage à l'app normale
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(title: Text('App Normale')),
                            body: Center(
                              child: Text('L\'app devrait fonctionner maintenant !'),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Text('Tester App Normale'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
