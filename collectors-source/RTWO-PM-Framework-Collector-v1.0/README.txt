RTWO PM Framework Collector v1.0
Motorola Edge 40 Pro (rtwo) / TWRP

OBJETIVO
Recopilar los archivos exactos de framework necesarios para construir un
parche reversible del Package Manager. Este ZIP NO modifica Android.

USO
1. Iniciar TWRP y desencriptar /data.
2. Install > seleccionar este ZIP > deslizar para flashear.
3. Buscar la salida en:
   /sdcard/RTWO-PM-COLLECTOR/<fecha-hora>/
   o el .zip/.tar.gz creado junto a esa carpeta.
4. Subir el archivo generado.

SEGURIDAD
- No remonta particiones como escritura.
- No instala módulos.
- No borra cachés.
- No modifica services.jar.
