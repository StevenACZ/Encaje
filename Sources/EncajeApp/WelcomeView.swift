import AppKit
import SwiftUI

struct WelcomeView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var permissions: PermissionCoordinator
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var entrance = false
  @State private var completing = false
  let sourceFrame: () -> CGRect?
  let finish: () -> Void

  var body: some View {
    VStack(spacing: 22) {
      Spacer(minLength: 0)
      ZStack {
        Circle().fill(.teal.opacity(0.10)).frame(width: 126, height: 126)
        if permissions.granted {
          Image(systemName: "checkmark.seal.fill").font(.system(size: 68)).foregroundStyle(
            .teal.gradient
          )
          .transition(.scale.combined(with: .opacity))
        } else {
          Image(nsImage: AppArtwork.icon).resizable().frame(
            width: 94, height: 94
          )
          .transition(.opacity)
        }
      }.scaleEffect(entrance ? 1 : 0.88)
      VStack(spacing: 10) {
        Text(
          model.ready
            ? localized("Everything fits.", "Todo encaja.")
            : localized("Welcome to Encaje", "Bienvenido a Encaje")
        )
        .font(.system(size: 30, weight: .bold, design: .rounded))
        Text(
          permissions.granted
            ? (model.ready
              ? localized(
                "Accessibility is enabled. Your windows are ready to move.",
                "Accesibilidad activada. Tus ventanas están listas para moverse.")
              : localized(
                "Accessibility is enabled. Finishing shortcut setup…",
                "Accesibilidad activada. Preparando los atajos…"))
            : localized(
              "One permission to put your windows in their place.",
              "Un permiso para poner tus ventanas en su sitio.")
        )
        .foregroundStyle(.secondary).multilineTextAlignment(.center)
      }
      VStack(alignment: .leading, spacing: 12) {
        Label(
          localized(
            "Arrange windows across all your displays", "Ordena ventanas entre todas tus pantallas"),
          systemImage: "rectangle.2.swap")
        Label(
          localized(
            "Repeat Shift + A / D / W / X to keep moving",
            "Repite Shift + A / D / W / X para seguir moviendo"), systemImage: "keyboard")
        Label(
          localized(
            "Shift + S maximizes on the current display", "Shift + S maximiza en la pantalla actual"
          ), systemImage: "arrow.up.left.and.arrow.down.right")
      }.font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
      Text(
        localized(
          "These shortcuts replace their uppercase letters. Pause or customize them from the menu bar.",
          "Estos atajos reemplazan sus letras mayúsculas. Páusalos o cámbialos desde la barra de menú."
        )
      )
      .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(
        horizontal: false, vertical: true)
      if permissions.restartSuggested && !model.shortcutReady {
        Button(localized("Restart Encaje to finish", "Reiniciar Encaje para terminar")) {
          permissions.restartApplication()
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        Text(
          localized(
            "Your setup will resume automatically.", "La configuración continuará automáticamente.")
        )
        .font(.caption).foregroundStyle(.secondary)
      } else if permissions.granted {
        Button(localized("Start using Encaje", "Empezar a usar Encaje"), action: complete)
          .buttonStyle(.borderedProminent).controlSize(.large).disabled(!model.ready)
      } else {
        Button(localized("Allow Accessibility", "Dar acceso a Accesibilidad")) {
          permissions.request(from: sourceFrame())
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        Text(
          localized(
            "Drag Encaje into the list, then enable its switch if asked.",
            "Arrastra Encaje a la lista y activa su interruptor si se solicita.")
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      if !model.ready {
        Button(localized("Set up later", "Configurar después"), action: finish).buttonStyle(.plain)
          .foregroundStyle(.secondary).font(.caption)
      }
    }.padding(32).frame(width: 510, height: 590).ignoresSafeArea(.container, edges: .top).tint(
      .teal
    )
    .animation(
      reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85),
      value: permissions.granted
    )
    .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { entrance = true } }
  }

  private func complete() {
    guard !completing, model.ready else { return }
    completing = true
    model.welcomeComplete = true
    finish()
  }
}
