import XCTest
@testable import Verity

final class VerityNativeIntegrationTests: XCTestCase {
    private func fixturePath(_ relativePath: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: relativePath,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw XCTSkip("Fixture not found: \(relativePath)")
        }
        return url.path
    }

    func testRuntimeModeMatchesNativeBuild() {
        XCTAssertEqual(Verity.runtimeMode, .native)
    }

    func testProveKitPrepareProveVerify() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)
        let proof = try scheme.prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        XCTAssertFalse(proof.data.isEmpty)
        XCTAssertTrue(try scheme.verifier.verify(proof: proof))
    }

    func testBarretenbergPrepareProveVerify() throws {
        let verity = try Verity(backend: .barretenberg)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)
        let proof = try scheme.prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        XCTAssertFalse(proof.data.isEmpty)
        XCTAssertTrue(try scheme.verifier.verify(proof: proof))
    }

    func testNativeLastErrorBufferIsEmptyWithoutFailure() throws {
        XCTAssertNil(try Verity.lastErrorMessage(for: .barretenberg))
        XCTAssertNil(try Verity.lastErrorMessage(for: .provekit))
    }
}
