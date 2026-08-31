import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class RtspCameraPage extends StatefulWidget {
  const RtspCameraPage({super.key});

  @override
  State<RtspCameraPage> createState() => _RtspCameraPageState();
}

class _RtspCameraPageState extends State<RtspCameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isStreaming = false;
  String? _localIp;
  bool _isVertical = true;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isGranted) {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _initCamera(_cameras![_selectedCameraIndex]);
      }
    }

    _localIp = await NetworkInfo().getWifiIP();
    setState(() {});
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _toggleStreaming() {
    setState(() {
      _isStreaming = !_isStreaming;
    });

    if (_isStreaming) {
      WakelockPlus.enable();
      // Em uma implementação real, aqui iniciaríamos o servidor RTSP nativo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transmissão Iniciada (Simulado)')),
      );
    } else {
      WakelockPlus.disable();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transmissão Interrompida')),
      );
    }
  }

  void _rotateCamera() {
    setState(() {
      _isVertical = !_isVertical;
    });
    // Forçar orientação
    if (_isVertical) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _initCamera(_cameras![_selectedCameraIndex]);
  }

  @override
  void dispose() {
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String rtspUrl = 'rtsp://${_localIp ?? "0.0.0.0"}:8554/live';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: _isVertical 
                  ? 1 / _controller!.value.aspectRatio 
                  : _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          const Text(
                            'Status:',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            _isStreaming ? 'TRANSMITINDO' : 'OFFLINE',
                            style: TextStyle(
                              color: _isStreaming ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.switch_camera, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Link Info
                if (_isStreaming)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purpleAccent),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Link RTSP para conexão:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 5),
                        SelectableText(
                          rtspUrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Controls
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isVertical ? Icons.screen_lock_portrait : Icons.screen_lock_landscape,
                        label: 'Rotacionar',
                        onTap: _rotateCamera,
                      ),
                      GestureDetector(
                        onTap: _toggleStreaming,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _isStreaming ? Colors.red : Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isStreaming ? Colors.red : Colors.green).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isStreaming ? Icons.stop : Icons.play_arrow,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _buildControlButton(
                        icon: Icons.flash_on,
                        label: 'Flash',
                        onTap: () {
                           _controller?.setFlashMode(
                             _controller!.value.flashMode == FlashMode.off 
                                ? FlashMode.torch 
                                : FlashMode.off
                           );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 30),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
