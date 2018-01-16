import Vapor
import FluentProvider
import Crypto
import Foundation

final class Token: Model {
    let storage = Storage()

    /// The actual token
    let token: String

    /// The identifier of the user to which the token belongs
    let userId: Identifier
    
    let expirationTime: String
    
    /// Creates a new Token
    init(string: String, user: User) throws {
        token = string
        userId = try user.assertExists()
        expirationTime = Date().exptFormatted
    }

    // MARK: Row

    init(row: Row) throws {
        token = try row.get("token")
        userId = try row.get(User.foreignIdKey)
        expirationTime = try row.get("expiration_time")
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set("token", token)
        try row.set(User.foreignIdKey, userId)
        try row.set("expiration_time", expirationTime)
        return row
    }
}

// MARK: Convenience

extension Token {
    /// Generates a new token for the supplied User.
    static func generate(for user: User) throws -> Token {
        // generate 128 random bits using OpenSSL
        let random = try Crypto.Random.bytes(count: 16)

        // create and return the new token
        return try Token(string: random.base64Encoded.makeString(), user: user)
    }
}

// MARK: Relations

extension Token {
    /// Fluent relation for accessing the user
    var user: Parent<Token, User> {
        return parent(id: userId)
    }
}

// MARK: Preparation

extension Token: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Tokens
    static func prepare(_ database: Database) throws {
        try database.create(Token.self) { builder in
            builder.id()
            builder.string("token")
            builder.foreignId(for: User.self)
            builder.date("expiration_time")
        }
    }

    /// Undoes what was done in `prepare`
    static func revert(_ database: Database) throws {
        try database.delete(Token.self)
    }
}

// MARK: JSON

/// Allows the token to convert to JSON.
extension Token: JSONRepresentable {
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set("token", token)
        return json
    }
}

// MARK: HTTP

/// Allows the Token to be returned directly in route closures.
extension Token: ResponseRepresentable { }

extension Date {
    /*
     An expiration time formatted date string
     */
    public var exptFormatted: String {
        return DateFormatter.sharedEXPTFormatter().string(from: self.addingTimeInterval(3600 * 24 * 7))
    }
}

extension String {
    public var expired: Bool {
        if let expireTime = DateFormatter.sharedEXPTFormatter().date(from: self) {
            return Date() > expireTime
        }else {
            return false
        }
    }
    
    public var inExpire: Bool {
        return !expired
    }
}

extension DateFormatter {
    static func sharedEXPTFormatter() -> DateFormatter {
        struct Static {
            static let singleton: DateFormatter = .makeEXPTFormatter()
        }
        return Static.singleton
    }
    static func makeEXPTFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}
