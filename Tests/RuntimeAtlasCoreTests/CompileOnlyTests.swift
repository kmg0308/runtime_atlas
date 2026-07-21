import RuntimeAtlasCore

// The selected standalone Command Line Tools image does not ship XCTest or
// Swift Testing. RuntimeAtlasSelfTest executes the assertions used by verify.sh;
// this target still guards the public test-consumer surface at compile time.
enum CompileOnlyTests {
    static func canConstructCoreTypes() {
        _ = EvidenceCounts()
        _ = DiscoveryAvailability.available
        _ = RuntimeAtlasConfiguration()
    }
}
