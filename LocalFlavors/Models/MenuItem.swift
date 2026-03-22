import Foundation

struct MenuItem: Identifiable, Codable {
    let id: String
    let name: String
    let price: String?
    let category: String?
    let description: String?

    init(id: String = UUID().uuidString, name: String, price: String?, category: String?, description: String?) {
        self.id = id
        self.name = name
        self.price = price
        self.category = category
        self.description = description
    }
}
