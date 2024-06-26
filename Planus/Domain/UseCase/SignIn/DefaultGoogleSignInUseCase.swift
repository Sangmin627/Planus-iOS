//
//  DefaultGoogleSignInUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/23.
//

import Foundation
import RxSwift

final class DefaultGoogleSignInUseCase: GoogleSignInUseCase {
    
    private let socialAuthRepository: SocialAuthRepository
    
    init(
        socialAuthRepository: SocialAuthRepository
    ) {
        self.socialAuthRepository = socialAuthRepository
    }
    
    func execute(code: String) -> Single<Token> {
        return socialAuthRepository
            .googleSignIn(code: code)
            .map {
                return $0.data.toDomain()
            }
    }
}
