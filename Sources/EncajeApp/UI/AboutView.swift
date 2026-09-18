import AppKit
import SwiftUI

struct AboutView: View {
  @ObservedObject private var updates = UpdateManager.shared

  private var version: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  }

  private var build: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
  }

  private var year: String {
    String(Calendar.current.component(.year, from: Date()))
  }

  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 10) {
        Image(nsImage: AppArtwork.icon).resizable().frame(width: 96, height: 96)
          .shadow(color: .teal.opacity(0.35), radius: 10, y: 5)
        Text("Encaje").font(.title.bold())
        Text("v\(version) · \(build)").font(.caption.monospaced()).foregroundStyle(.secondary)
        updateStatus
      }
      Text(localized("Your space, your way.", "Tu espacio, a tu manera."))
        .font(.callout).foregroundStyle(.secondary)
      HStack(spacing: 8) {
        chip(symbol: "rectangle.split.2x2", label: localized("Zones", "Zonas"))
        chip(symbol: "keyboard", label: localized("Shortcuts", "Atajos"))
        chip(symbol: "rectangle.3.group", label: localized("Workspaces", "Espacios"))
      }
      Rectangle().fill(.secondary.opacity(0.18)).frame(height: 1)
      HStack(spacing: 10) {
        link(
          symbol: "link", label: "GitHub", url: "https://github.com/StevenACZ/Encaje")
        link(
          symbol: "ladybug", label: localized("Report an issue", "Reportar problema"),
          url: "https://github.com/StevenACZ/Encaje/issues")
      }
      VStack(spacing: 3) {
        Text(localized("Made with care for macOS", "Creado con cuidado para macOS"))
          .font(.caption).foregroundStyle(.tertiary)
        Text("© \(year) StevenACZ").font(.caption2).foregroundStyle(.tertiary)
      }
    }.padding(.horizontal, 26).padding(.top, 24).padding(.bottom, 18).frame(width: 380)
      .fixedSize(horizontal: false, vertical: true)
      .background(Color(nsColor: .windowBackgroundColor)).tint(.teal)
  }

  @ViewBuilder private var updateStatus: some View {
    switch updates.phase {
    case .idle:
      switch updates.manualCheckStatus {
      case .checking:
        HStack(spacing: 5) {
          ProgressView().controlSize(.mini)
          Text(localized("Checking for updates…", "Buscando actualizaciones…")).font(.caption2)
            .foregroundStyle(.secondary)
        }
      case .upToDate:
        capsule(
          symbol: "checkmark.circle",
          text: localized("You're up to date", "Tienes la última versión"))
      case .failed:
        Button {
          updates.checkForUpdatesManually()
        } label: {
          capsule(
            symbol: "exclamationmark.arrow.circlepath",
            text: localized("Could not check. Try again", "No se pudo comprobar. Reintentar"))
        }.buttonStyle(.plain)
      case .idle:
        Button {
          updates.checkForUpdatesManually()
        } label: {
          Text(localized("Check for updates", "Buscar actualizaciones")).font(.caption2)
            .foregroundStyle(.secondary).underline().padding(.vertical, 3)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
      }
    case .available(let version):
      VStack(spacing: 5) {
        Button {
          updates.installPendingUpdate()
        } label: {
          capsule(
            symbol: "arrow.down.circle",
            text: localized("Install update", "Instalar actualización")
              + (version.isEmpty ? "" : " · " + version))
        }.buttonStyle(.plain)
        if updates.releasePageURL != nil {
          Button {
            updates.openReleasePage()
          } label: {
            Text(localized("Release notes", "Ver notas de la versión")).font(.caption2)
              .foregroundStyle(.secondary).underline().padding(.vertical, 3)
              .contentShape(Rectangle())
          }.buttonStyle(.plain)
        }
      }
    case .downloading(let fraction):
      progressCapsule(
        text: localized("Downloading update…", "Descargando actualización…"),
        percent: fraction.map { Int(($0 * 100).rounded()) })
    case .readyToInstall(let version):
      VStack(spacing: 5) {
        Button {
          updates.installNow()
        } label: {
          capsule(
            symbol: "checkmark.circle.fill",
            text: localized("Install now", "Instalar ahora")
              + (version.isEmpty ? "" : " · " + version))
        }.buttonStyle(.plain)
        Button {
          updates.installLater()
        } label: {
          Text(localized("Later", "Más tarde")).font(.caption2).foregroundStyle(.secondary)
            .underline().padding(.vertical, 3).contentShape(Rectangle())
        }.buttonStyle(.plain)
      }
    case .installing:
      progressCapsule(text: localized("Installing and restarting…", "Instalando y reiniciando…"))
    case .failed:
      Button {
        updates.installNow()
      } label: {
        capsule(
          symbol: "exclamationmark.arrow.circlepath",
          text: localized("Update failed. Retry", "La actualización falló. Reintentar"))
      }.buttonStyle(.plain)
    }
  }

  private func capsule(symbol: String, text: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol).font(.caption2)
      Text(text).font(.caption2.weight(.medium))
    }.padding(.horizontal, 10).padding(.vertical, 5)
      .background(Capsule().fill(.teal.opacity(0.12)))
      .overlay(Capsule().strokeBorder(.teal.opacity(0.22), lineWidth: 1))
      .foregroundStyle(.teal).contentShape(Capsule())
  }

  private func progressCapsule(text: String, percent: Int? = nil) -> some View {
    HStack(spacing: 6) {
      ProgressView().controlSize(.mini)
      Text(text).font(.caption2.weight(.medium))
      if let percent {
        Text("\(percent) %").font(.caption2.monospacedDigit())
      }
    }.padding(.horizontal, 10).padding(.vertical, 5)
      .background(Capsule().fill(.teal.opacity(0.12)))
      .overlay(Capsule().strokeBorder(.teal.opacity(0.22), lineWidth: 1))
      .foregroundStyle(.teal)
  }

  private func chip(symbol: String, label: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol).font(.caption2)
      Text(label).font(.caption2.weight(.medium))
    }.padding(.horizontal, 10).padding(.vertical, 5)
      .background(Capsule().fill(.teal.opacity(0.12)))
      .overlay(Capsule().strokeBorder(.teal.opacity(0.22), lineWidth: 1))
      .foregroundStyle(.teal)
  }

  private func link(symbol: String, label: String, url: String) -> some View {
    Button {
      if let target = URL(string: url) { NSWorkspace.shared.open(target) }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: symbol).font(.caption)
        Text(label).font(.caption.weight(.medium))
      }.padding(.horizontal, 12).padding(.vertical, 7)
        .background(
          RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.secondary.opacity(0.08))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(.secondary.opacity(0.16), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }.buttonStyle(.plain)
  }
}
