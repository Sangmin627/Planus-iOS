//
//  URLPool.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/04.
//

import Foundation

struct URLPool {
    typealias Base = BaseURL
    typealias Path = URLPathComponent
    
    static let todo = Base.main() + Path.app + Path.todos
    static let calendar = Base.main() + Path.app + Path.todos + Path.calendar
    static let categories = Base.main() + Path.app + Path.categories
    static let members = Base.main() + Path.app + Path.members
    static let refreshToken = Base.main() + Path.app + Path.auth + Path.tokenReissue
    static let oauthKakao = Base.main() + Path.app + Path.oauth + Path.login + Path.kakao
    static let oauthGoogle = Base.main() + Path.app + Path.oauth + Path.login + Path.google
    static let oauthAppleSignIn = Base.main() + Path.app + Path.oauth + Path.login + Path.apple
    static let oauthAppleSecret = Base.main() + Path.app + Path.oauth + Path.apple + "/client-secret"
    static let oauthAppleToken = "https://appleid.apple.com/auth/token"
    static let oauthAppleRevoke = "https://appleid.apple.com/auth/revoke"
    static let groups = Base.main() + Path.app + Path.groups
    static let groupJoin = Base.main() + Path.app + Path.joins
    static let myGroup = Base.main() + Path.app + Path.myGroups
    static let search = Base.main() + Path.app + Path.groups + Path.search
}
