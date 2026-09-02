# SenpAI Mobile Companion 🥋

Aplicativo mobile desenvolvido em **Flutter** com integração nativa **Android Kotlin** para transmissão de vídeo RTSP em tempo real com aceleração de hardware.

---

## 🎨 Design e Tema (Mon-Bunbukan)

* **Estilo Monocromático**: Cores em tons de preto, branco e cinza escuro para uma interface minimalista e elegante.
* **Marca d'Água Mon-Bunbukan**: Padrão de fundo em ladrilho repetido (`assets/mon-bunbukan.png`) com opacidade sutil (0.03 a 0.05).
* **Tela Inicial (`WelcomePage`)**:
  * Apresenta o Kanji `先輩` (Senpai).
  * Botão "ENTRAR" que navega para o menu principal.
* **Menu Principal (`MenuPage`)**:
  * Botão de Logout no cabeçalho.
  * Cartão **SenpAI Camera** para abrir a câmera RTSP nativa.
  * Cartão de **Configurações**.

---

## 📹 SenpAI Camera (Transmissão RTSP Nativa)

### Arquitetura Nativa no Android

Em dispositivos de alta performance como o **Motorola Edge 50 Pro**, servidores puramente em Dart / HTTP MJPEG apresentavam limitações no ecossistema Camera2 (`Unsupported set of inputs/outputs provided` e `Previous capture has not returned yet`).

A solução utiliza uma **Activity Nativa dedicada (`RtspCameraActivity.kt`)** invocada via `MethodChannel` Flutter (`com.senpai.senpaimobile/rtsp` -> `openRtspCamera`).

### Características Técnicas

* **Codificação de Vídeo**: H.264 (1280x720 @ 30 FPS) com aceleração de hardware via GPU.
* **Codificação de Áudio**: AAC (32kHz Stereo).
* **Preview em Tempo Real**: `OpenGlView` com aceleração OpenGL ES.
* **Servidor e Relay RTSP 1.0**:
  * Escuta na porta padrão **8554**.
  * Suporta os comandos RTSP 1.0 (`OPTIONS`, `DESCRIBE`, `SETUP`, `PLAY`, `RECORD`, `TEARDOWN`).
  * Envia parâmetros SDP dinâmicos (SPS/PPS).
  * Realiza o relay dos pacotes RTP binários ($) diretamente para clientes como VLC, OBS ou gravadores NVR.
* **URL de Conexão na Rede Local**:
  ```text
  rtsp://<IP-DO-CELULAR>:8554/live
  ```

### Controles e Interface Otimizados

* **Ícone Play / Stop (200x200px)**: Inicia ou encerra a transmissão RTSP.
* **Girar Tela (140x140px)**: Alterna a orientação da câmera entre Retrato e Paisagem.
* **Lanterna / Flash (140x140px)**: Liga ou desliga o LED da câmera.
* **Trocar Câmera (110x110px)**: Alterna entre a câmera traseira e frontal.
* **Fechar (110x110px)**: Retorna ao menu do aplicativo Flutter.
* **Cópia do Link**: Toque no cartão do endereço RTSP para copiar a URL automaticamente.

---

## ⚙️ Configuração de Build e Dependências

* **SDK Android**:
  * `compileSdk = 37`
  * `targetSdk = 37`
* **Repositório JitPack**: Configurado no `android/settings.gradle.kts` e `android/build.gradle.kts` (`https://jitpack.io`).
* **Biblioteca Nativa**: PedroSG94 RootEncoder (`com.github.pedroSG94.RootEncoder:library:2.4.3`, `:encoder:2.4.3`, `:rtsp:2.4.3`).
* **Permissões Declaradas (`AndroidManifest.xml`)**:
  * `android.permission.CAMERA`
  * `android.permission.RECORD_AUDIO`
  * `android.permission.INTERNET`
  * `android.permission.ACCESS_WIFI_STATE`
  * `android.permission.WAKE_LOCK`

---

## 🚀 Como Conectar no VLC Media Player

1. Abra o aplicativo no dispositivo Android e acesse o menu.
2. Toque na opção **SenpAI Camera**.
3. Toque no botão **Play** central para ativar o servidor RTSP (o status mudará para **SERVIDOR RTSP ATIVO**).
4. No computador (conectado à mesma rede Wi-Fi), abra o **VLC Media Player**.
5. Vá em `Mídia` -> `Abrir Transmissão de Rede` (Ctrl + N).
6. Digite a URL exibida no aplicativo, por exemplo:
   ```text
   rtsp://192.168.100.171:8554/live
   ```
7. Clique em **Reproduzir**.
