import Foundation
import CommonCrypto

actor FileHashService {
    static let shared = FileHashService()

    func md5(url: URL) async -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fileHandle.close() }

        var context = CC_MD5_CTX()
        CC_MD5_Init(&context)

        let chunkSize = 1024 * 1024
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return false }
            data.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                CC_MD5_Update(&context, baseAddress, CC_LONG(buffer.count))
            }
            return true
        }) {}

        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func sha256(url: URL) async -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fileHandle.close() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        let chunkSize = 1024 * 1024
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return false }
            data.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                CC_SHA256_Update(&context, baseAddress, CC_LONG(buffer.count))
            }
            return true
        }) {}

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
