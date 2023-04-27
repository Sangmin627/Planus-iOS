//
//  TokenDTO.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/27.
//

import Foundation

struct TokenRequestDTO: Codable {
    var accessToken: String
    var refreshToken: String
}

struct TokenResponseDataDTO: Codable {
    var accessToken: String
    var refreshToken: String
}

extension TokenResponseDataDTO {
    func toDomain() -> Token {
        return Token(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
