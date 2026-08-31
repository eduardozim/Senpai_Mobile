import 'package:flutter/material.dart';
import 'rtsp_camera_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SenpAI Menu'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            title: 'Câmera RTSP',
            subtitle: 'Transmitir vídeo pela rede local',
            icon: Icons.videocam,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RtspCameraPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            title: 'Configurações',
            subtitle: 'Ajustes do aplicativo',
            icon: Icons.settings,
            onTap: () {
              // TODO: Implement settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Icon(icon, size: 40, color: Colors.purpleAccent),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
