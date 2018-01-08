import Vapor
import AuthProvider

class PassportCollection: RouteCollection {
    func build(_ builder: RouteBuilder) {
        // create a new user
        //
        // POST /users
        // <json containing new user information>
        builder.post("users") { req in
            // require that the request body be json
            guard let json = req.json else {
                throw Abort(.badRequest)
            }
            
            // initialize the name and email from
            // the request json
            let user = try User(json: json)
            
            // ensure no user with this email already exists
            guard try User.makeQuery().filter("email", user.email).first() == nil else {
                throw Abort(.badRequest, reason: "A user with that email already exists.")
            }
            
            // require a plaintext password is supplied
            guard let password = json["password"]?.string else {
                throw Abort(.badRequest)
            }
            
            // hash the password and set it on the user
            let config = try Config()
            try config.setup()
            let drop = try Droplet(config)
            user.password = try drop.hash.make(password.makeBytes()).makeString()
            
            // save and return the new user
            try user.save()
            return user
        }
        
        let password = builder.grouped([
            PasswordAuthenticationMiddleware(User.self)
            ])
        
        password.post("signin") { req in
            let user = try req.user()
            let token = try Token.generate(for: user)
            try token.save()
            return token
        }
        
        let token = builder.grouped([
            TokenAuthenticationMiddleware(User.self)
            ])
        
        // simply returns a greeting to the user that has been authed
        // using the token middleware.
        //
        // GET /me
        // Authorization: Bearer <token from /login>
        token.get("me") { req in
            let user = try req.user()
            return "Hello, \(user.name)"
        }
    }
}

