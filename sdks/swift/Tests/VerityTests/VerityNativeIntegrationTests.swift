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

    func testProveKitLoadProveVerify() throws {
        let verity = try Verity(backend: .provekit)
        let prover = try verity.loadProver(from: fixturePath("prover.pkp"))
        let verifier = try verity.loadVerifier(from: fixturePath("verifier.pkv"))
        let proof = try prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        XCTAssertFalse(proof.data.isEmpty)
        XCTAssertTrue(try verifier.verify(proof: proof))
    }

    func testBarretenbergIsUnavailableInNativeMobileArtifact() {
        XCTAssertThrowsError(try Verity(backend: .barretenberg)) { error in
            XCTAssertEqual(error as? VerityError, .unknownBackend)
        }
    }

    func testNativeLastErrorBufferIsEmptyWithoutFailure() throws {
        XCTAssertNil(try Verity.lastErrorMessage(for: .provekit))
        XCTAssertThrowsError(try Verity.lastErrorMessage(for: .barretenberg)) { error in
            XCTAssertEqual(error as? VerityError, .unknownBackend)
        }
    }

    func testAsyncProveKitLoadProveVerify() async throws {
        let verity = try Verity(backend: .provekit)
        let prover = try await verity.loadProver(from: fixturePath("prover.pkp"))
        let verifier = try await verity.loadVerifier(from: fixturePath("verifier.pkv"))
        let witness = try Witness.load(from: fixturePath("Prover.toml"))
        let proof = try await prover.prove(witness: witness)
        XCTAssertFalse(proof.data.isEmpty)
        let valid = try await verifier.verify(proof: proof)
        XCTAssertTrue(valid)
    }

    func testMmapLoadProveVerify() throws {
        let verity = try Verity(backend: .provekit)
        let prover = try verity.loadProver(mappedFrom: fixturePath("prover.pkp"))
        let verifier = try verity.loadVerifier(mappedFrom: fixturePath("verifier.pkv"))
        let proof = try prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        XCTAssertFalse(proof.data.isEmpty)
        XCTAssertTrue(try verifier.verify(proof: proof))
    }

    func testAsyncMmapLoadProveVerify() async throws {
        let verity = try Verity(backend: .provekit)
        let prover = try await verity.loadProver(mappedFrom: fixturePath("prover.pkp"))
        let verifier = try await verity.loadVerifier(mappedFrom: fixturePath("verifier.pkv"))
        let witness = try Witness.load(from: fixturePath("Prover.toml"))
        let proof = try await prover.prove(witness: witness)
        XCTAssertFalse(proof.data.isEmpty)
        let valid = try await verifier.verify(proof: proof)
        XCTAssertTrue(valid)
    }

    func testMmapLoadNonexistentFileThrows() {
        let verity = try! Verity(backend: .provekit)
        XCTAssertThrowsError(try verity.loadProver(mappedFrom: "/nonexistent/prover.pkp")) { error in
            XCTAssertEqual(error as? VerityError, .schemeReadError)
        }
    }
}
