import Foundation
import SwiftData

@Model
final class ImagineProviderConfig {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var modelName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        baseURL: String = "",
        modelName: String = ""
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.modelName = modelName
        self.createdAt = Date()
    }
}
