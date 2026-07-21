import RuntimeAtlasCore
import SwiftUI

private struct AtlasCopyEnvironmentKey: EnvironmentKey {
    static let defaultValue = AtlasCopy(language: .english)
}

extension EnvironmentValues {
    var atlasCopy: AtlasCopy {
        get { self[AtlasCopyEnvironmentKey.self] }
        set { self[AtlasCopyEnvironmentKey.self] = newValue }
    }
}
