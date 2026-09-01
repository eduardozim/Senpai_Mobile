import 'package:flutter/material.dart';
import 'rtsp_camera_page.dart';
import 'welcome_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'SenpAI Menu'.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w300, letterSpacing: 2),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomePage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.03,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/mon-bunbukan.png'),
                  repeat: ImageRepeat.repeat,
                  scale: 6.0,
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            children: [
              _buildMenuCard(
                context,
                title: 'Câmera RTSP',
                subtitle: 'Transmitir vídeo local',
                icon: Icons.videocam_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const RtspCameraPage()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildMenuCard(
                context,
                title: 'Configurações',
                subtitle: 'Ajustes do sistema',
                icon: Icons.settings_outlined,
                onTap: () {
                  // TODO: Implement settings
                },
              ),
            ],
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
    // CORREÇÃO: Usando Material para evitar o erro de InkSplash e DecoratedBox
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        shape: Border.all(color: Colors.black12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Icon(icon, size: 30, color: Colors.black),
          title: Text(
            title.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.black26),
          onTap: onTap,
        ),
      ),
    );
  }
}
