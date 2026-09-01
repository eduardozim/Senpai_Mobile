import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
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
  
  HttpServer? _server;
  final StreamController<Uint8List> _frameStream = StreamController<Uint8List>.broadcast();
  Timer? _timer;
  bool _isCapturing = false;

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
    if (mounted) setState(() {});
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // Motorola Edge 50 suporta bem 480p/720p
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Erro câmera: $e');
    }
  }

  Future<void> _startServer() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler((shelf.Request request) {
      if (request.url.path == 'live') {
        return shelf.Response.ok(
          _frameStream.stream,
          headers: {
            'Content-Type': 'multipart/x-mixed-replace; boundary=frame',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Pragma': 'no-cache',
          },
        );
      }
      return shelf.Response.notFound('Not Found');
    });

    try {
      _server = await io.serve(handler, '0.0.0.0', 8554);
      
      // Loop de captura seguro (1 frame a cada 300ms = ~3 FPS)
      // O segredo para não crashar o Motorola é o flag _isCapturing
      _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
        if (_isStreaming && !_isCapturing && _controller != null && _controller!.value.isInitialized) {
          _isCapturing = true;
          try {
            final XFile file = await _controller!.takePicture();
            final bytes = await file.readAsBytes();
            
            _frameStream.add(Uint8List.fromList([
              ...ascii.encode('--frame\r\n'),
              ...ascii.encode('Content-Type: image/jpeg\r\n'),
              ...ascii.encode('Content-Length: ${bytes.length}\r\n\r\n'),
              ...bytes,
              ...ascii.encode('\r\n'),
            ]));
            
            // Limpeza imediata do arquivo temporário
            File(file.path).delete().catchError((e) => debugPrint(e.toString()));
          } catch (e) {
            debugPrint('Erro frame: $e');
          } finally {
            _isCapturing = false;
          }
        }
      });
    } catch (e) {
      debugPrint('Erro servidor: $e');
    }
  }

  Future<void> _stopServer() async {
    _timer?.cancel();
    await _server?.close(force: true);
    _server = null;
  }

  void _toggleStreaming() async {
    if (!_isStreaming) {
      await _startServer();
      if (mounted) setState(() { _isStreaming = true; });
      WakelockPlus.enable();
    } else {
      await _stopServer();
      if (mounted) setState(() { _isStreaming = false; });
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _stopServer();
    _controller?.dispose();
    WakelockPlus.disable();
    _frameStream.close();
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

    final String streamUrl = 'rtsp://${_localIp ?? "0.0.0.0"}:8554/live';

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
                            _isStreaming ? 'STREAMING ON' : 'OFFLINE',
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
                        onPressed: () {
                          _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
                          _initCamera(_cameras![_selectedCameraIndex]);
                        },
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
                          'LINK PARA CONEXÃO (VLC)',
                          style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          streamUrl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '* Funciona também via HTTP no Browser',
                          style: TextStyle(color: Colors.grey, fontSize: 8),
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
                      IconButton(
                        icon: Icon(
                          _isVertical ? Icons.stay_current_portrait : Icons.stay_current_landscape,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() { _isVertical = !_isVertical; });
                          if (_isVertical) {
                            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                          } else {
                            SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
                          }
                        },
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
                      IconButton(
                        icon: const Icon(Icons.flash_on, color: Colors.white),
                        onPressed: () {
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
}
