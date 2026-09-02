package com.senpai.senpaimobile

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.net.wifi.WifiManager
import android.os.Bundle
import android.text.format.Formatter
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.*
import com.pedro.common.ConnectChecker
import com.pedro.library.rtsp.RtspCamera2
import com.pedro.library.view.OpenGlView
import java.io.InputStream
import java.io.OutputStream
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.util.ArrayList
import java.util.Collections
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.thread

class RtspCameraActivity : Activity(), ConnectChecker {

    private lateinit var openGlView: OpenGlView
    private lateinit var rtspCamera2: RtspCamera2
    private var isStreaming = false
    private var isVertical = true
    private var isLanternOn = false
    private var localIp = "0.0.0.0"

    private lateinit var statusText: TextView
    private lateinit var playButton: ImageView
    private lateinit var urlCard: LinearLayout
    private lateinit var urlText: TextView

    private var serverSocket: ServerSocket? = null
    private var isServerRunning = false
    private val viewerOutputs = CopyOnWriteArrayList<OutputStream>()
    private var currentSdp = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        localIp = getLocalIpAddress()

        // Root FrameLayout
        val rootLayout = FrameLayout(this)
        rootLayout.setBackgroundColor(Color.BLACK)

        // 1. OpenGL View (Camera Preview)
        openGlView = OpenGlView(this)
        val previewParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        rootLayout.addView(openGlView, previewParams)

        // Initialize RTSP Camera
        rtspCamera2 = RtspCamera2(openGlView, this)

        // 2. Overlay UI
        val overlayLayout = LinearLayout(this)
        overlayLayout.orientation = LinearLayout.VERTICAL
        val overlayParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        rootLayout.addView(overlayLayout, overlayParams)

        // Top Header
        val topBar = LinearLayout(this)
        topBar.orientation = LinearLayout.HORIZONTAL
        topBar.setBackgroundColor(Color.parseColor("#80000000"))
        topBar.setPadding(30, 30, 30, 30)
        topBar.gravity = Gravity.CENTER_VERTICAL

        val closeBtn = ImageView(this)
        closeBtn.setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
        closeBtn.setColorFilter(Color.WHITE)
        closeBtn.setOnClickListener { finish() }
        topBar.addView(closeBtn, LinearLayout.LayoutParams(110, 110))

        val statusLayout = LinearLayout(this)
        statusLayout.orientation = LinearLayout.VERTICAL
        statusLayout.gravity = Gravity.CENTER
        val statusParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)

        val statusLabel = TextView(this)
        statusLabel.text = "STATUS"
        statusLabel.setTextColor(Color.LTGRAY)
        statusLabel.textSize = 12f
        statusLabel.gravity = Gravity.CENTER

        statusText = TextView(this)
        statusText.text = "OFFLINE"
        statusText.setTextColor(Color.WHITE)
        statusText.textSize = 16f
        statusText.gravity = Gravity.CENTER

        statusLayout.addView(statusLabel)
        statusLayout.addView(statusText)
        topBar.addView(statusLayout, statusParams)

        val switchCamBtn = ImageView(this)
        switchCamBtn.setImageResource(android.R.drawable.ic_menu_camera)
        switchCamBtn.setColorFilter(Color.WHITE)
        switchCamBtn.setOnClickListener {
            try {
                rtspCamera2.switchCamera()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        topBar.addView(switchCamBtn, LinearLayout.LayoutParams(110, 110))

        overlayLayout.addView(topBar)

        // Spacer
        val spacer = View(this)
        overlayLayout.addView(spacer, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        // RTSP Link Card
        urlCard = LinearLayout(this)
        urlCard.orientation = LinearLayout.VERTICAL
        urlCard.setBackgroundColor(Color.parseColor("#CC000000"))
        urlCard.setPadding(30, 20, 30, 20)
        urlCard.gravity = Gravity.CENTER
        urlCard.visibility = View.GONE

        val urlTitle = TextView(this)
        urlTitle.text = "LINK RTSP PARA CONEXÃO (VLC / NVR)"
        urlTitle.setTextColor(Color.LTGRAY)
        urlTitle.textSize = 12f

        urlText = TextView(this)
        urlText.text = "rtsp://$localIp:8554/live"
        urlText.setTextColor(Color.WHITE)
        urlText.textSize = 18f
        urlText.setPadding(0, 10, 0, 10)
        urlText.setOnClickListener {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("RTSP Link", urlText.text)
            clipboard.setPrimaryClip(clip)
            Toast.makeText(this, "Link RTSP copiado!", Toast.LENGTH_SHORT).show()
        }

        val urlTip = TextView(this)
        urlTip.text = "* Servidor RTSP Nativo Ativo. Toque para copiar o link."
        urlTip.setTextColor(Color.GRAY)
        urlTip.textSize = 11f

        urlCard.addView(urlTitle)
        urlCard.addView(urlText)
        urlCard.addView(urlTip)

        val cardMargin = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        cardMargin.setMargins(50, 0, 50, 20)
        overlayLayout.addView(urlCard, cardMargin)

        // Bottom Bar Controls
        val bottomBar = LinearLayout(this)
        bottomBar.orientation = LinearLayout.HORIZONTAL
        bottomBar.setBackgroundColor(Color.parseColor("#80000000"))
        bottomBar.setPadding(40, 40, 40, 40)
        bottomBar.gravity = Gravity.CENTER

        // Rotate Button
        val rotateBtn = ImageView(this)
        rotateBtn.setImageResource(android.R.drawable.ic_menu_always_landscape_portrait)
        rotateBtn.setColorFilter(Color.WHITE)
        rotateBtn.setOnClickListener {
            isVertical = !isVertical
            requestedOrientation = if (isVertical) {
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            } else {
                ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
        }
        val btnParams = LinearLayout.LayoutParams(140, 140)
        btnParams.setMargins(40, 0, 40, 0)
        bottomBar.addView(rotateBtn, btnParams)

        // Play/Stop Button
        playButton = ImageView(this)
        playButton.setImageResource(android.R.drawable.ic_media_play)
        playButton.setColorFilter(Color.WHITE)
        playButton.setOnClickListener {
            toggleStreaming()
        }
        val playParams = LinearLayout.LayoutParams(200, 200)
        playParams.setMargins(50, 0, 50, 0)
        bottomBar.addView(playButton, playParams)

        // Flash Button
        val flashBtn = ImageView(this)
        flashBtn.setImageResource(android.R.drawable.ic_menu_compass)
        flashBtn.setColorFilter(Color.WHITE)
        flashBtn.setOnClickListener {
            try {
                if (isLanternOn) {
                    rtspCamera2.disableLantern()
                    isLanternOn = false
                } else {
                    rtspCamera2.enableLantern()
                    isLanternOn = true
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        bottomBar.addView(flashBtn, btnParams)

        overlayLayout.addView(bottomBar)

        setContentView(rootLayout)
    }

    private fun startRtspServer() {
        if (isServerRunning) return
        isServerRunning = true
        currentSdp = "v=0\r\no=- 0 0 IN IP4 $localIp\r\ns=SenpAI RTSP Camera\r\nc=IN IP4 $localIp\r\nt=0 0\r\nm=video 0 RTP/AVP 96\r\na=rtrmap:96 H264/90000\r\na=fmtp:96 packetization-mode=1\r\na=control:streamid=0\r\nm=audio 0 RTP/AVP 97\r\na=rtrmap:97 MPEG4-GENERIC/32000/2\r\na=fmtp:97 profile-level-id=1; mode=AAC-hbr; config=1290; sizelength=13; indexlength=3; indexdeltalength=3\r\na=control:streamid=1\r\n"

        thread {
            try {
                serverSocket = ServerSocket(8554)
                while (isServerRunning) {
                    val socket = serverSocket?.accept() ?: break
                    handleRtspClient(socket)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun handleRtspClient(socket: Socket) {
        thread {
            try {
                val input = socket.getInputStream()
                val output = socket.getOutputStream()
                var isViewerRegistered = false

                while (socket.isConnected && isServerRunning) {
                    val req = readRtspRequest(input) ?: break

                    if (req == "$") {
                        // Binary RTP Interleaved frame
                        val channel = input.read()
                        val lenHigh = input.read()
                        val lenLow = input.read()
                        if (channel == -1 || lenHigh == -1 || lenLow == -1) break
                        val length = (lenHigh shl 8) or lenLow
                        val payload = ByteArray(length)
                        var readBytes = 0
                        while (readBytes < length) {
                            val r = input.read(payload, readBytes, length - readBytes)
                            if (r == -1) break
                            readBytes += r
                        }

                        // Broadcast binary RTP frame to all active VLC/NVR viewer sockets
                        if (viewerOutputs.isNotEmpty()) {
                            val frameHeader = byteArrayOf(0x24.toByte(), channel.toByte(), lenHigh.toByte(), lenLow.toByte())
                            for (vOut in viewerOutputs) {
                                try {
                                    vOut.write(frameHeader)
                                    vOut.write(payload)
                                    vOut.flush()
                                } catch (_: Exception) {
                                    viewerOutputs.remove(vOut)
                                }
                            }
                        }
                    } else {
                        // Text RTSP Header command
                        var cseq = "1"
                        val cseqIdx = req.indexOf("CSeq:")
                        if (cseqIdx != -1) {
                            val endIdx = req.indexOf("\r\n", cseqIdx)
                            if (endIdx != -1) {
                                cseq = req.substring(cseqIdx + 5, endIdx).trim()
                            }
                        }

                        // Read SDP body for ANNOUNCE if Content-Length present
                        var requestBody = ""
                        val clIdx = req.indexOf("Content-Length:")
                        if (clIdx != -1) {
                            val clEnd = req.indexOf("\r\n", clIdx)
                            if (clEnd != -1) {
                                val contentLenStr = req.substring(clIdx + 15, clEnd).trim()
                                val contentLen = try { contentLenStr.toInt() } catch (e: Exception) { 0 }
                                if (contentLen > 0) {
                                    val bodyBytes = ByteArray(contentLen)
                                    var rCount = 0
                                    while (rCount < contentLen) {
                                        val r = input.read(bodyBytes, rCount, contentLen - rCount)
                                        if (r == -1) break
                                        rCount += r
                                    }
                                    requestBody = java.lang.String(bodyBytes, StandardCharsets.UTF_8).toString()
                                }
                            }
                        }

                        if (req.indexOf("ANNOUNCE") == 0) {
                            if (requestBody.length > 0) {
                                currentSdp = requestBody
                            }
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\n\r\n"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                        } else if (req.indexOf("OPTIONS") == 0) {
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nPublic: OPTIONS, DESCRIBE, SETUP, TEARDOWN, PLAY, PAUSE, ANNOUNCE, RECORD\r\n\r\n"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                        } else if (req.indexOf("DESCRIBE") == 0) {
                            val sdpBytes = currentSdp.toByteArray(StandardCharsets.UTF_8)
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nContent-Type: application/sdp\r\nContent-Length: ${sdpBytes.size}\r\n\r\n$currentSdp"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                        } else if (req.indexOf("SETUP") == 0) {
                            var streamId = "0"
                            if (req.indexOf("streamid=1") != -1) streamId = "1"
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nTransport: RTP/AVP/TCP;unicast;interleaved=${if (streamId == "0") "0-1" else "2-3"}\r\nSession: 12345678\r\n\r\n"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                        } else if (req.indexOf("PLAY") == 0) {
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nSession: 12345678\r\nRange: npt=0.000-\r\n\r\n"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                            if (!isViewerRegistered) {
                                viewerOutputs.add(output)
                                isViewerRegistered = true
                                runOnUiThread {
                                    Toast.makeText(this, "Cliente VLC conectado!", Toast.LENGTH_SHORT).show()
                                }
                            }
                        } else if (req.indexOf("RECORD") == 0) {
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nSession: 12345678\r\n\r\n"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                        } else if (req.indexOf("TEARDOWN") == 0) {
                            val response = "RTSP/1.0 200 OK\r\nCSeq: $cseq\r\n\r\n"
                            output.write(response.toByteArray(StandardCharsets.UTF_8))
                            output.flush()
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                try { socket.close() } catch (_: Exception) {}
            }
        }
    }

    private fun readRtspRequest(input: InputStream): String? {
        val bytes = ArrayList<Byte>()
        while (true) {
            val b = input.read()
            if (b == -1) {
                if (bytes.isEmpty()) return null
                break
            }
            bytes.add(b.toByte())
            val size = bytes.size
            if (size == 1 && bytes.get(0) == 0x24.toByte()) {
                return "$"
            }
            if (size >= 4 &&
                bytes.get(size - 4) == 13.toByte() && bytes.get(size - 3) == 10.toByte() &&
                bytes.get(size - 2) == 13.toByte() && bytes.get(size - 1) == 10.toByte()
            ) {
                break
            }
        }
        val arr = ByteArray(bytes.size)
        for (i in 0 until bytes.size) {
            arr[i] = bytes.get(i)
        }
        return java.lang.String(arr, StandardCharsets.UTF_8).toString()
    }

    private fun stopRtspServer() {
        isServerRunning = false
        try {
            serverSocket?.close()
            serverSocket = null
        } catch (_: Exception) {}
        viewerOutputs.clear()
    }

    private fun toggleStreaming() {
        if (!isStreaming) {
            startRtspServer()
            if (rtspCamera2.prepareVideo(1280, 720, 30, 1200 * 1024, 0) && rtspCamera2.prepareAudio()) {
                rtspCamera2.startStream("rtsp://127.0.0.1:8554/live")
                isStreaming = true
                statusText.text = "SERVIDOR RTSP ATIVO"
                statusText.setTextColor(Color.GREEN)
                playButton.setImageResource(android.R.drawable.ic_media_pause)
                urlCard.visibility = View.VISIBLE
            } else {
                Toast.makeText(this, "Erro ao preparar codificador de vídeo/áudio", Toast.LENGTH_SHORT).show()
            }
        } else {
            rtspCamera2.stopStream()
            stopRtspServer()
            isStreaming = false
            statusText.text = "OFFLINE"
            statusText.setTextColor(Color.WHITE)
            playButton.setImageResource(android.R.drawable.ic_media_play)
            urlCard.visibility = View.GONE
        }
    }

    private fun getLocalIpAddress(): String {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val ipAddress = wifiManager?.connectionInfo?.ipAddress ?: 0
            if (ipAddress != 0) {
                return Formatter.formatIpAddress(ipAddress)
            }
            val netInterfaces = NetworkInterface.getNetworkInterfaces()
            if (netInterfaces != null) {
                for (networkInterface in Collections.list(netInterfaces)) {
                    for (address in Collections.list(networkInterface.inetAddresses)) {
                        val host = address.hostAddress
                        if (!address.isLoopbackAddress && !host.isNullOrEmpty() && !host.contains(':')) {
                            return host
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return "0.0.0.0"
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isStreaming) {
            rtspCamera2.stopStream()
            stopRtspServer()
        }
    }

    // ConnectChecker callbacks
    override fun onConnectionStarted(url: String) {
        runOnUiThread {
            Toast.makeText(this, "Conexão de fluxo RTSP iniciada", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onConnectionSuccess() {
        runOnUiThread {
            Toast.makeText(this, "Servidor RTSP transmitindo!", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onConnectionFailed(reason: String) {
        runOnUiThread {
            Toast.makeText(this, "Erro no RTSP: $reason", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onDisconnect() {
        runOnUiThread {
            Toast.makeText(this, "Transmissão encerrada", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onAuthError() {}
    override fun onAuthSuccess() {}
    override fun onNewBitrate(bitrate: Long) {}
}
