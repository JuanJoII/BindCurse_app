# BindCurse App & Server UDP ⛧

Cliente móvil en Flutter y servidor receptor en Python para transmisión de micrófono en tiempo real en formato **PCM 16-bit 48kHz mono** a través de **UDP crudo de baja latencia**, con interfaz de usuario inspirada en el proyecto Stitch **"BindCurse app"** (tema Obsidian Audio).

---

## 🚀 Inicio Rápido

### 1. Iniciar el Servidor UDP (en tu PC / Mac / Linux)

El archivo [`bindcurse_server.py`](file:///C:/Users/57314/Desktop/Dev_Projects/bind_curse_app/bindcurse_server.py) ya está listo en el proyecto. No requiere librerías externas para funcionar (incluye modo VU meter en consola y guardado en archivo WAV).

```bash
# Modo básico con medidor VU en la terminal (puerto 9920 por defecto):
python bindcurse_server.py --vu

# Con guardado de sesión a archivo WAV:
python bindcurse_server.py --vu -o sesion_audio.wav

# Con reproducción en altavoces en vivo (opcional, instalar sounddevice):
# pip install sounddevice numpy
python bindcurse_server.py --play --vu
```

El servidor anunciará su presencia en la red local y responderá automáticamente a las solicitudes de vinculación de la app.

---

### 2. Iniciar la App en Flutter

```bash
flutter run
```

---

## 🛠️ Características Implementadas

### 1. Conexión Real y Validación de Red
- **Handshake Obligatorio**: Al pulsar *Vincular Audio (Bind)*, la app envía `BINDCURSE_HELLO` al host y puerto especificados. Si no hay un servidor escuchando o el puerto está cerrado, la conexión no se inicia y se muestra el mensaje de error con diagnóstico claro.
- **Heartbeat (PING/PONG)**: La app intercambia pings cada 2 segundos para medir el RTT en milisegundos reales. Si el servidor no responde en 6 segundos, el estado cambia automáticamente a `Enlace Caído`.
- **Rastreo y Autodescubrimiento LAN**: En la pestaña **Dispositivos**, el botón *Rastrear Señal* envía un broadcast UDP `BINDCURSE_DISCOVER` por la subred. Cualquier servidor activo responde con `BINDCURSE_HERE` y aparece al instante para ser vinculado o guardado con un solo toque.

### 2. Analizador de Espectro Real (FFT de 2048 puntos)
- **Cero simulaciones o números aleatorios**: Se eliminaron los timers que generaban ondas ficticias.
- **Mapeo Frecuencial Preciso**: El módulo [`SpectrumAnalyzer`](file:///C:/Users/57314/Desktop/Dev_Projects/bind_curse_app/lib/services/spectrum_analyzer.dart) aplica una ventana de Hann y FFT radix-2 sobre las muestras de micrófono para descomponer el audio en 15 bandas logarítmicas (60 Hz a 16 kHz) con tilt acústico y medidor RMS en dBFS real.
- **Modo Monitor**: Puedes activar el botón **MONITOR** en la parte superior derecha de la tarjeta para calibrar y ver la respuesta de tu micrófono en vivo antes de iniciar la transmisión UDP.

### 3. Protocolo de Transmisión UDP (`BCPM`)
- **Header binario de 8 bytes**: Magic byte `BCPM` (4 bytes) + Número de secuencia `uint32` en Little Endian para rastreo de paquetes perdidos.
- **Audio Crudo**: PCM 16-bit signed LE, 48000 Hz, 1 canal (mono).
- **Selector de Latencia**:
  - **Ultra Baja**: Paquetes de 10 ms (960 bytes).
  - **Estudio**: Paquetes de 20 ms (1920 bytes).
  - **Segura**: Paquetes de 48 ms (4608 bytes).
