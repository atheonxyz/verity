import XCTest
@testable import Verity

final class VerityUnitTests: XCTestCase {
    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testRuntimeModeIsRecognized() {
        XCTAssertTrue([RuntimeMode.sourceOnly, .native].contains(Verity.runtimeMode))
    }

    func testWitnessLoadNonexistentPath() {
        XCTAssertThrowsError(try Witness.load(from: "/nonexistent/Prover.toml"))
    }

    func testEmptyWitnessValuesThrows() {
        let witness = Witness(values: [:])
        XCTAssertThrowsError(try witness.resolve())
    }

    func testWitnessFromJson() throws {
        let witness = try Witness(json: #"{"x":"5"}"#)
        switch try witness.resolve() {
        case .json(let json):
            XCTAssertTrue(json.contains(#""x":"5""#))
        case .tomlPath:
            XCTFail("Expected JSON witness")
        }
    }

    func testWitnessFromInvalidJsonThrows() {
        XCTAssertThrowsError(try Witness(json: "[1,2,3]"))
        XCTAssertThrowsError(try Witness(json: "{"))
    }

    func testProofFromBytes() {
        let proof = Proof.fromBytes(Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(proof.size, 3)
    }

    func testProofHexPreview() {
        let proof = Proof.fromBytes(Data(repeating: 0x42, count: 12))
        XCTAssertEqual(proof.hexPreview(maxBytes: 4), "42424242...")
    }

    func testErrorCodeMapping() {
        XCTAssertEqual(VerityError.fromCode(9), .unknownBackend)
        XCTAssertEqual(VerityError.fromCode(10), .outOfMemory)
        XCTAssertEqual(VerityError.resourceClosed("FFI handle is closed"), .resourceClosed("FFI handle is closed"))
    }

    func testVersionIsNotEmpty() {
        XCTAssertFalse(Verity.version.isEmpty)
    }

    func testClosedSchemeOperationsThrowResourceClosed() {
        let prover = ProverScheme()
        let verifier = VerifierScheme()

        XCTAssertThrowsError(try prover.serialize()) { error in
            XCTAssertEqual(error as? VerityError, .resourceClosed("FFI handle is closed"))
        }
        XCTAssertThrowsError(try verifier.serialize()) { error in
            XCTAssertEqual(error as? VerityError, .resourceClosed("FFI handle is closed"))
        }
    }

    func testSwiftDispatchUsesCoreSymlink() throws {
        let dispatchPath = repoRoot().appendingPathComponent("sdks/swift/VerityDispatch").path
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: dispatchPath)
        XCTAssertEqual(destination, "../../core/dispatcher")
    }

    func testHexAllByteValues() {
        let allBytes = Data(0...255)
        let expected = (0...255).map { String(format: "%02x", $0) }.joined()
        let proof = Proof(data: allBytes)
        XCTAssertEqual(proof.hex, expected)
    }

    func testHexEmptyProof() {
        let proof = Proof(data: Data())
        XCTAssertEqual(proof.hex, "")
    }

    func testHexPreviewAllBytes() {
        let proof = Proof(data: Data(0...255))
        let preview = proof.hexPreview(maxBytes: 4)
        XCTAssertEqual(preview, "00010203...")
    }

    func testHexPreviewShortProof() {
        let proof = Proof(data: Data([0xab, 0xcd]))
        XCTAssertEqual(proof.hexPreview(maxBytes: 4), "abcd")
    }
}
