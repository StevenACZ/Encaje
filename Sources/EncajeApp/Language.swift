import Foundation

enum AppLanguage: String, CaseIterable {
  case system
  case spanish = "es"
  case english = "en"

  static var defaults: UserDefaults {
    ProcessInfo.processInfo.environment["ENCAJE_DEFAULTS_SUITE"]
      .flatMap(UserDefaults.init(suiteName:)) ?? .standard
  }

  var label: String {
    switch self {
    case .system: localized("System", "Sistema")
    case .spanish: "Español"
    case .english: "English"
    }
  }
}

func localized(_ english: String, _ spanish: String) -> String {
  let selection =
    AppLanguage(rawValue: AppLanguage.defaults.string(forKey: "language") ?? "") ?? .system
  let useSpanish =
    selection == .spanish
    || (selection == .system && Locale.preferredLanguages.first?.hasPrefix("es") == true)
  return useSpanish ? spanish : english
}
