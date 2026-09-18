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
            localized("Install update", "Instalar actualización")
              + (version.isEmpty ? "" : " · " + version),
            systemImage: "arrow.down.circle")
        }
      case .downloading(let fraction):
        VStack(alignment: .leading, spacing: 5) {
          Text(localized("Downloading update…", "Descargando actualización…"))
          if let fraction {
            HStack(spacing: 8) {
              ProgressView(value: fraction)
              Text("\(Int((fraction * 100).rounded())) %").font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          } else {
            ProgressView().controlSize(.small)
          }
        }
      case .readyToInstall(let version):
        HStack(spacing: 8) {
          Button(
            localized("Install now", "Instalar ahora") + (version.isEmpty ? "" : " · " + version)
          ) {
            updates.installNow()
          }
          Button(localized("Later", "Más tarde")) {
            updates.installLater()
          }
        }
      case .installing:
        Label(
          localized("Installing and restarting…", "Instalando y reiniciando…"),
          systemImage: "arrow.triangle.2.circlepath")
      case .failed:
        Button(localized("Update failed. Retry", "La actualización falló. Reintentar")) {
          updates.installNow()
        }
      }
    }.font(.callout).frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct UpdateCardView: View {
  @ObservedObject private var updates = UpdateManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(.teal)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.subheadline.weight(.semibold))
          if let subtitle {
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }
      controls
    }.padding(12)
      .background(RoundedRectangle(cornerRadius: 12).fill(.teal.opacity(0.12)))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.teal.opacity(0.22), lineWidth: 1))
      .contentShape(RoundedRectangle(cornerRadius: 12))
      .animation(.easeInOut(duration: 0.25), value: updates.phase)
  }

  private var version: String {
    switch updates.phase {
    case .available(let version), .readyToInstall(let version), .failed(let version):
      return version
    case .idle, .downloading, .installing:
      return updates.pendingVersion ?? ""
    }
  }

  private var symbol: String {
    switch updates.phase {
    case .idle, .available: return "arrow.down.circle.fill"
    case .downloading: return "arrow.down.circle"
    case .readyToInstall: return "checkmark.circle.fill"
    case .installing: return "arrow.triangle.2.circlepath"
    case .failed: return "exclamationmark.arrow.circlepath"
    }
  }

  private var title: String {
    switch updates.phase {
    case .idle, .available:
      return version.isEmpty
        ? localized("A new version is available", "Nueva versión disponible")
        : localized("Version \(version) is available", "Nueva versión v\(version) disponible")
    case .downloading:
      return version.isEmpty
        ? localized("Downloading update…", "Descargando actualización…")
        : localized("Downloading v\(version)…", "Descargando v\(version)…")
    case .readyToInstall:
      return version.isEmpty
        ? localized("Update ready to install", "Actualización lista para instalar")
        : localized("v\(version) ready to install", "v\(version) lista para instalar")
    case .installing:
      return version.isEmpty
        ? localized("Installing update…", "Instalando actualización…")
        : localized("Installing v\(version)…", "Instalando v\(version)…")
    case .failed:
      return localized("Update failed", "No se pudo actualizar")
    }
  }

  private var subtitle: String? {
    switch updates.phase {
    case .idle, .available:
      return localized("One-click download and install", "Descarga e instalación en un clic")
    case .downloading:
      return nil
    case .readyToInstall:
      return localized(
        "The app will quit and reopen by itself", "La app se cerrará y volverá a abrir sola")
    case .installing:
      return localized("Restarting in a moment", "Se reiniciará en un momento")
    case .failed:
      return localized(
        "Check your connection and try again", "Revisa tu conexión e inténtalo de nuevo")
    }
  }

  @ViewBuilder private var controls: some View {
    switch updates.phase {
    case .idle:
      EmptyView()
    case .available:
      prominentButton(localized("Update", "Actualizar")) { updates.installPendingUpdate() }
    case .downloading(let fraction):
      HStack(spacing: 8) {
        if let fraction {
          ProgressView(value: fraction).progressViewStyle(.linear).tint(.teal)
          Text("\(Int((fraction * 100).rounded())) %").font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        } else {
          ProgressView().progressViewStyle(.linear).tint(.teal)
        }
      }
    case .readyToInstall:
      HStack(spacing: 8) {
        prominentButton(localized("Install now", "Instalar ahora")) { updates.installNow() }
        Button {
          updates.installLater()
        } label: {
          Text(localized("Later", "Más tarde")).frame(maxWidth: .infinity).padding(.vertical, 6)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.secondary)
      }
    case .installing:
      ProgressView().progressViewStyle(.linear).tint(.teal)
    case .failed:
      prominentButton(localized("Retry", "Reintentar")) { updates.installNow() }
    }
  }

  private func prominentButton(_ text: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(text).frame(maxWidth: .infinity).contentShape(Rectangle())
    }.buttonStyle(.borderedProminent).tint(.teal)
  }
}
