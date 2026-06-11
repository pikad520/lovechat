import Foundation

/// 生成图片的本地存储（research R6）：
/// ~/Library/Application Support/LoveChat/Images/{uuid}.png
/// 消息只持有相对文件名（FR-022）。
enum ImageStore {

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("LoveChat/Images", isDirectory: true)
    }

    /// 写入图片字节，返回相对文件名
    static func save(_ data: Data) throws -> String {
        let directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".png"
        try data.write(to: directory.appendingPathComponent(fileName))
        return fileName
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func load(_ fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
