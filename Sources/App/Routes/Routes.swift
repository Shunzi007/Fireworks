import Vapor

final class Routes: RouteCollection {
    let view: ViewRenderer
    init(_ view: ViewRenderer) {
        self.view = view
    }

    func build(_ builder: RouteBuilder) throws {
        /// GET /
        builder.get { req in
            return try self.view.make("welcome")
        }
        
        builder.get("plaintext") { req in
            return "Hello, world!"
        }

        /// GET /hello/...
        builder.resource("hello", HelloController(view))

        // response to requests to /info domain
        // with a description of the request
        builder.get("info") { req in
            return req.description
        }
        
        try builder.resource("posts", PostController.self)
        
        try builder.grouped("passport").collection(PassportCollection())
        // Authed to protect
        let tokenMiddleware = TokenAuthenticationMiddleware(User.self)
        let authed = builder.grouped(tokenMiddleware)
        
        let infoHandler: RouteHandler = { req in
            let user = try req.user()
            return "Hello, \(user.name)"
        }
        authed.post("info", handler: infoHandler)
        authed.get("info", handler: infoHandler)
        authed.put("info", handler: infoHandler)

            
    }
}
