import XCTest
@testable import Verity

final class VerityTests: XCTestCase {

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

    // MARK: - ProveKit

    func testProveKitPrepareProveVerify() throws {
        let verity = try Verity(backend: .provekit)

        let scheme = try verity.prepare(circuit: fixturePath("circuit.json"))

        let proof = try verity.prove(
            with: scheme.prover,
            input: fixturePath("Prover.toml")
        )
        XCTAssertFalse(proof.isEmpty, "Proof should not be empty")

        let valid = try verity.verify(with: scheme.verifier, proof: proof)
        XCTAssertTrue(valid, "ProveKit proof should verify")
    }

    func testProveKitSchemeReuse() throws {
        let verity = try Verity(backend: .provekit)
        let scheme = try verity.prepare(circuit: fixturePath("circuit.json"))

        let proof1 = try verity.prove(with: scheme.prover, input: fixturePath("Prover.toml"))
        let proof2 = try verity.prove(with: scheme.prover, input: fixturePath("Prover.toml"))

        XCTAssertTrue(try verity.verify(with: scheme.verifier, proof: proof1))
        XCTAssertTrue(try verity.verify(with: scheme.verifier, proof: proof2))
    }

    func testProveKitSaveLoadRoundTrip() throws {
        let verity = try Verity(backend: .provekit)
        let scheme = try verity.prepare(circuit: fixturePath("circuit.json"))

        let tmpDir = NSTemporaryDirectory() + "verity_test_save"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let proverPath = tmpDir + "/prover.pkp"
        let verifierPath = tmpDir + "/verifier.pkv"
        try scheme.prover.save(to: proverPath)
        try scheme.verifier.save(to: verifierPath)

        let loadedProver = try verity.loadProver(from: proverPath)
        let loadedVerifier = try verity.loadVerifier(from: verifierPath)

        let proof = try verity.prove(with: loadedProver, input: fixturePath("Prover.toml"))
        let valid = try verity.verify(with: loadedVerifier, proof: proof)
        XCTAssertTrue(valid, "Loaded scheme should prove and verify")
    }

    func testProveKitSerializeBytesRoundTrip() throws {
        let verity = try Verity(backend: .provekit)
        let scheme = try verity.prepare(circuit: fixturePath("circuit.json"))

        let proverBytes = try scheme.prover.serialize()
        let verifierBytes = try scheme.verifier.serialize()

        XCTAssertFalse(proverBytes.isEmpty)
        XCTAssertFalse(verifierBytes.isEmpty)

        let restoredProver = try verity.loadProver(data: proverBytes)
        let restoredVerifier = try verity.loadVerifier(data: verifierBytes)

        let proof = try verity.prove(with: restoredProver, input: fixturePath("Prover.toml"))
        let valid = try verity.verify(with: restoredVerifier, proof: proof)
        XCTAssertTrue(valid, "Bytes round-trip should prove and verify")
    }

    // MARK: - Barretenberg

    func testBarretenbergPrepareProveVerify() throws {
        let verity = try Verity(backend: .barretenberg)

        let scheme = try verity.prepare(circuit: fixturePath("circuit.json"))

        let proof = try verity.prove(
            with: scheme.prover,
            input: fixturePath("Prover.toml")
        )
        XCTAssertFalse(proof.isEmpty, "Proof should not be empty")

        let valid = try verity.verify(with: scheme.verifier, proof: proof)
        XCTAssertTrue(valid, "Barretenberg proof should verify")
    }
}
