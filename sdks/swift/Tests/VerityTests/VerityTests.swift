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

    private func fixtureURL(_ relativePath: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: relativePath,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw XCTSkip("Fixture not found: \(relativePath)")
        }
        return url
    }

    // MARK: - Circuit Loading

    func testCircuitLoadFromPath() throws {
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        XCTAssertFalse(circuit.data.isEmpty, "Circuit data should not be empty")
    }

    func testCircuitLoadFromURL() throws {
        let circuit = try Circuit.load(url: fixtureURL("circuit.json"))
        XCTAssertFalse(circuit.data.isEmpty, "Circuit data should not be empty")
    }

    func testCircuitLoadNonexistentPath() {
        XCTAssertThrowsError(try Circuit.load(from: "/nonexistent/circuit.json")) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    // MARK: - ProveKit

    func testProveKitPrepareProveVerify() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))

        let scheme = try verity.prepare(circuit: circuit)

        let proof = try scheme.prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        XCTAssertFalse(proof.data.isEmpty, "Proof should not be empty")
        XCTAssertGreaterThan(proof.size, 0)
        XCTAssertFalse(proof.hex.isEmpty)

        let valid = try scheme.verifier.verify(proof: proof)
        XCTAssertTrue(valid, "ProveKit proof should verify")
    }

    func testProveKitSchemeReuse() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)

        let witness = try Witness.load(from: fixturePath("Prover.toml"))
        let proof1 = try scheme.prover.prove(witness: witness)
        let proof2 = try scheme.prover.prove(witness: witness)

        XCTAssertTrue(try scheme.verifier.verify(proof: proof1))
        XCTAssertTrue(try scheme.verifier.verify(proof: proof2))
    }

    func testProveKitSaveLoadRoundTrip() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)

        let tmpDir = NSTemporaryDirectory() + "verity_test_save"
        try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        let proverPath = tmpDir + "/prover.pkp"
        let verifierPath = tmpDir + "/verifier.pkv"
        try scheme.prover.save(to: proverPath)
        try scheme.verifier.save(to: verifierPath)

        let loadedProver = try verity.loadProver(from: proverPath)
        let loadedVerifier = try verity.loadVerifier(from: verifierPath)

        let proof = try loadedProver.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        let valid = try loadedVerifier.verify(proof: proof)
        XCTAssertTrue(valid, "Loaded scheme should prove and verify")
    }

    func testProveKitSerializeBytesRoundTrip() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)

        let proverBytes = try scheme.prover.serialize()
        let verifierBytes = try scheme.verifier.serialize()

        XCTAssertFalse(proverBytes.isEmpty)
        XCTAssertFalse(verifierBytes.isEmpty)

        let restoredProver = try verity.loadProver(data: proverBytes)
        let restoredVerifier = try verity.loadVerifier(data: verifierBytes)

        let proof = try restoredProver.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        let valid = try restoredVerifier.verify(proof: proof)
        XCTAssertTrue(valid, "Bytes round-trip should prove and verify")
    }

    // MARK: - Barretenberg

    func testBarretenbergPrepareProveVerify() throws {
        let verity = try Verity(backend: .barretenberg)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))

        let scheme = try verity.prepare(circuit: circuit)

        let proof = try scheme.prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))
        XCTAssertFalse(proof.data.isEmpty, "Proof should not be empty")

        let valid = try scheme.verifier.verify(proof: proof)
        XCTAssertTrue(valid, "Barretenberg proof should verify")
    }

    // MARK: - Proof Type

    func testProofHexPreview() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)
        let proof = try scheme.prover.prove(witness: try Witness.load(from: fixturePath("Prover.toml")))

        let preview = proof.hexPreview(maxBytes: 8)
        XCTAssertTrue(preview.hasSuffix("..."), "Preview should be truncated")
        // 8 bytes = 16 hex chars + "..."
        XCTAssertEqual(preview.count, 19)
    }

    // MARK: - Witness

    func testWitnessLoadNonexistentPath() {
        XCTAssertThrowsError(try Witness.load(from: "/nonexistent/Prover.toml")) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    func testEmptyWitnessValuesThrows() {
        let witness = Witness(values: [:])
        XCTAssertThrowsError(try witness.resolve()) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    // MARK: - Negative Tests

    func testPrepareNonexistentCircuit() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = Circuit(data: Data("{}".utf8))
        XCTAssertThrowsError(try verity.prepare(circuit: circuit)) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    func testProveNonexistentInput() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)
        XCTAssertThrowsError(try scheme.prover.prove(witness: try Witness.load(from:"/nonexistent/Prover.toml"))) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    func testVerifyGarbageProof() throws {
        let verity = try Verity(backend: .provekit)
        let circuit = try Circuit.load(from: fixturePath("circuit.json"))
        let scheme = try verity.prepare(circuit: circuit)
        let garbage = Proof(data: Data(repeating: 0x42, count: 128))
        let result = try scheme.verifier.verify(proof: garbage)
        XCTAssertFalse(result, "Garbage proof should not verify")
    }

    func testLoadProverNonexistentPath() throws {
        let verity = try Verity(backend: .provekit)
        XCTAssertThrowsError(try verity.loadProver(from: "/nonexistent/prover.pkp")) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    func testLoadVerifierNonexistentPath() throws {
        let verity = try Verity(backend: .provekit)
        XCTAssertThrowsError(try verity.loadVerifier(from: "/nonexistent/verifier.pkv")) { error in
            XCTAssertTrue(error is VerityError, "Expected VerityError, got \(error)")
        }
    }

    func testErrorCodeMapping() {
        XCTAssertNotNil(VerityError.fromCode(1).errorDescription)
        XCTAssertNotNil(VerityError.fromCode(2).errorDescription)
        XCTAssertNotNil(VerityError.fromCode(4).errorDescription)
        XCTAssertNotNil(VerityError.fromCode(5).errorDescription)
        XCTAssertNotNil(VerityError.fromCode(8).errorDescription)
        XCTAssertNotNil(VerityError.fromCode(9).errorDescription)
        XCTAssertNotNil(VerityError.fromCode(999).errorDescription)
    }

    func testVersionIsNotEmpty() {
        XCTAssertFalse(Verity.version.isEmpty, "Version should not be empty")
    }
}
