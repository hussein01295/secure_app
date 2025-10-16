import 'package:flutter/material.dart';
import 'package:silencia/core/service/socket_service.dart';

/// Widget de debug pour surveiller et contrôler la connexion socket
class ConnectionDebugWidget extends StatefulWidget {
  const ConnectionDebugWidget({super.key});

  @override
  State<ConnectionDebugWidget> createState() => _ConnectionDebugWidgetState();
}

class _ConnectionDebugWidgetState extends State<ConnectionDebugWidget> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    final socketService = SocketService();
    final isConnected = socketService.isConnected;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
            title: Text(
              isConnected ? 'Connecté' : 'Déconnecté',
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isConnected 
                ? 'Socket connecté au serveur'
                : 'Socket déconnecté - reconnexion en cours...',
            ),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Actions de debug',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            socketService.forceReconnect();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reconnexion forcée lancée'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reconnecter'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await socketService.resetConnection();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Connexion réinitialisée'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              setState(() {}); // Refresh UI
                            }
                          },
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isConnected) {
                        socketService.stopReconnection();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reconnexion automatique arrêtée'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        socketService.startReconnection();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reconnexion automatique redémarrée'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      setState(() {});
                    },
                    icon: Icon(isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      isConnected ? 'Arrêter auto-reconnexion' : 'Démarrer auto-reconnexion',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Statut détaillé',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Socket initialisé: ${socketService.isReady}'),
                        Text('Socket connecté: ${socketService.isConnected}'),
                        const SizedBox(height: 4),
                        const Text(
                          'Vérifiez les logs de la console pour plus de détails',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
