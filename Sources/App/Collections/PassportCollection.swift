import Vapor
import AuthProvider
import FluentProvider

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
            user.password = try Droplet.configed().hash.make(password.makeBytes()).makeString()
            
            // save and return the new user
            try user.save()
            return user
        }
        
        let password = builder.grouped([
            PasswordAuthenticationMiddleware(User.self)
            ])
        
        password.post("signin") { req in
            let user = try req.user()
            let tokens = try Token.makeQuery().filter("user_id", .equals, user.id).all()
            if let token = tokens.first, token.expirationTime.inExpire {
                return token
            }else {
                try tokens.forEach({ try $0.delete() })
                let token = try Token.generate(for: user)
                try token.save()
                return token
            }
        }

    }
}

