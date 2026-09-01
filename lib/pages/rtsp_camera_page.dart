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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.black,
          content: Text('Transmissão Iniciada'),
        ),
      );
    } else {
      WakelockPlus.disable();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.black,
          content: Text('Transmissão Interrompida'),
        ),
      );
    }
  }

  void _rotateCamera() {
    setState(() {
      _isVertical = !_isVertical;
    });
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
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final String rtspUrl = 'rtsp://${_localIp ?? "0.0.0.0"}:8554/live';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _isVertical 
                  ? 1 / _controller!.value.aspectRatio 
                  : _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          const Text(
                            'STATUS',
                            style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                          ),
                          Text(
                            _isStreaming ? 'TRANSMITINDO' : 'OFFLINE',
                            style: TextStyle(
                              color: _isStreaming ? Colors.greenAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isStreaming)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'LINK RTSP',
                          style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          rtspUrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isVertical ? Icons.stay_current_portrait : Icons.stay_current_landscape,
                        label: 'ROTACIONAR',
                        onTap: _rotateCamera,
                      ),
                      GestureDetector(
                        onTap: _toggleStreaming,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _isStreaming ? Colors.white : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            _isStreaming ? Icons.stop : Icons.play_arrow,
                            size: 40,
                            color: _isStreaming ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      _buildControlButton(
                        icon: _controller!.value.flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                        label: 'FLASH',
                        onTap: () {
                           _controller?.setFlashMode(
                             _controller!.value.flashMode == FlashMode.off 
                                ? FlashMode.torch 
                                : FlashMode.off
                           );
                           setState(() {});
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
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1),
        ),
      ],
    );
  }
}
