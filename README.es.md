<p align="center"><img src="Assets/AppIcon.png" width="112" height="112" alt="Icono de Encaje"></p>
<h1 align="center">Encaje</h1>
<p align="center">Tu espacio, a tu manera.</p>
<p align="center"><a href="README.md">English</a> · <strong>Español</strong></p>
<p align="center">
  <a href="https://github.com/StevenACZ/Encaje/releases/latest">Descargar para macOS</a> ·
  <a href="CHANGELOG.md">Novedades</a> ·
  <a href="https://github.com/StevenACZ/Encaje/issues">Reportar un problema</a>
</p>

Encaje es un gestor de ventanas nativo para macOS y Apple Silicon. Dibuja tus
propias zonas, asigna atajos y mueve ventanas entre monitores. No requiere cuenta.

![Zonas de ventanas y atajos personalizables en Encaje](docs/images/zones.png)

## Qué puedes hacer

- Crear zonas arrastrando sobre una cuadrícula, con controles exactos de posición y tamaño.
- Asignar atajos que combinen Command, Option, Control y Shift.
- Deshacer y rehacer cambios de la cuadrícula, y comparar zonas con contornos de referencia.
- Mover ventanas entre monitores vecinos repitiendo un atajo direccional.
- Guardar espacios de trabajo y restaurar la posición de las ventanas abiertas que coincidan.
- Pausar desde la barra de menús o excluir aplicaciones de los atajos.
- Ajustar el espaciado y el inicio de sesión opcional, con una guía nativa de Accesibilidad.
- Cambiar al instante entre inglés, español y el idioma del sistema.
- Recibir actualizaciones firmadas mediante Sparkle 2, con comprobaciones diarias
  opcionales y una acción explícita para instalar.

## Instalación

Requiere **macOS 14 o posterior y un Mac con Apple Silicon**.

1. Descarga el DMG más reciente desde [Releases](https://github.com/StevenACZ/Encaje/releases/latest).
2. Arrastra Encaje a Aplicaciones y ábrelo.
3. Sigue la guía para activar Encaje en Ajustes del Sistema → Privacidad y
   seguridad → Accesibilidad. Reinicia Encaje si la guía lo solicita.
4. Abre la configuración desde la barra de menús para personalizar zonas y atajos.

**Los atajos predeterminados con Shift interceptan las letras mayúsculas
correspondientes en otras aplicaciones.** Por ejemplo, Shift+Q mueve una ventana
en vez de escribir Q. Cambia los atajos, pausa Encaje o excluye las aplicaciones
donde necesites esas teclas.

| Atajo predeterminado | Zona |
| --- | --- |
| Shift + Q / W / E | Superior izquierda / área superior / superior derecha |
| Shift + A / S / D | Izquierda / maximizar / derecha |
| Shift + Z / X / C | Inferior izquierda / área inferior / inferior derecha |

## A tu medida

Arrastra sobre la cuadrícula de una zona para definir sus límites. Los controles
de ajuste fino permiten indicar celdas exactas y elegir entre 1 y 64 filas y
columnas. Command+Z deshace un cambio; Command+Shift+Z lo rehace. Las otras zonas
pueden mostrarse como referencia sin modificar sus dimensiones guardadas.

Al repetir un atajo direccional, la ventana ocupa su zona y después continúa hacia
un monitor vecino. Mantener la tecla pulsada no recorre los monitores de golpe;
maximizar conserva el monitor actual. Cada aplicación puede imponer límites al
tamaño de sus ventanas. Se omiten las ventanas minimizadas y a pantalla completa.

Los espacios de trabajo restauran ventanas que ya están abiertas; no inician
aplicaciones ni vuelven a abrir documentos. Las ventanas con título necesitan una
coincidencia única. Los nombres personalizados y ajustes permanecen en tu Mac.

## Privacidad y actualizaciones

Accesibilidad permite mover ventanas y gestionar atajos. Encaje no solicita
Grabación de pantalla, Micrófono, Acceso total al disco ni Automatización. Consulta
[seguridad y privacidad](SECURITY.md) para conocer el manejo de datos y cómo
reportar vulnerabilidades.

Las versiones públicas pueden buscar actualizaciones diariamente si activas esa
opción. La instalación requiere una acción tuya. Las compilaciones de desarrollo
no reciben actualizaciones públicas.

## Desarrollo y contribuciones

Encaje utiliza Swift 6, SwiftPM, AppKit y SwiftUI, con Sparkle 2 para actualizarse.
Consulta las guías de [desarrollo](docs/development.md),
[validación](docs/validation.md), [contribuciones](CONTRIBUTING.md) y
[publicación](docs/releasing.md), disponibles en inglés.

## Licencia

[MIT](LICENSE)
