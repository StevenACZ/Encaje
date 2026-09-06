import SwiftUI

struct UpdateSettingsView: View {
  @ObservedObject private var updates = UpdateManager.shared

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Label(localized("Updates", "Actualizaciones"), systemImage: "arrow.down.circle")
            .font(.headline)
          Spacer()
          Text(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
          )
          .foregroundStyle(.secondary)
        }
        if updates.available {
          Toggle(
            localized("Check automatically", "Buscar automáticamente"),
            isOn: Binding(
              get: { updates.autoCheckEnabled }, set: { updates.setAutoCheckEnabled($0) }))
          UpdateActionView()
        } else {
          Text(
            localized(
              "Development builds are updated through the development installer.",
              "Las versiones de desarrollo se actualizan mediante su instalador.")
          )
          .font(.caption).foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading).padding(9)
    }
  }
}

struct UpdateActionView: View {
  @ObservedObject private var updates = UpdateManager.shared

  var body: some View {
    Group {
      switch updates.phase {
      case .idle:
        switch updates.manualCheckStatus {
        case .checking:
          Label(
            localized("Checking for updates…", "Buscando actualizaciones…"),
            systemImage: "arrow.clockwise")
        case .upToDate:
          Label(
            localized("You're up to date", "Tienes la última versión"),
            systemImage: "checkmark.circle")
        case .failed:
          Button(localized("Could not check. Try again", "No se pudo comprobar. Reintentar")) {
            updates.checkForUpdatesManually()
          }
        case .idle:
          Button(localized("Check for updates", "Buscar actualizaciones")) {
            updates.checkForUpdatesManually()
          }
        }
      case .available(let version):
        Button {
          updates.installPendingUpdate()
        } label: {
          Label(
            localized("Install update", "Instalar actualización") + " · " + version,
            systemImage: "arrow.down.circle")
        }
      case .downloading(let fraction):
        VStack(alignment: .leading, spacing: 5) {
          Text(localized("Downloading update…", "Descargando actualización…"))
          if let fraction {
            ProgressView(value: fraction)
          } else {
            ProgressView().controlSize(.small)
          }
        }
      case .installing:
        Label(
          localized("Installing and restarting…", "Instalando y reiniciando…"),
          systemImage: "arrow.triangle.2.circlepath")
      case .failed:
        Button(localized("Update failed. Retry", "La actualización falló. Reintentar")) {
          updates.installPendingUpdate()
        }
      }
    }.font(.callout).frame(maxWidth: .infinity, alignment: .leading)
  }
}
