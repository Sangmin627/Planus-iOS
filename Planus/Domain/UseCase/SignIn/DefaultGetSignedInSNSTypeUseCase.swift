//
//  DefaultGetSignedInSNSTypeUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/13.
//

import Foundation

final class DefaultGetSignedInSNSTypeUseCase: GetSignedInSNSTypeUseCase {
    private let socialAuthRepository: SocialAuthRepository
    
    init(socialAuthRepository: SocialAuthRepository) {
        self.socialAuthRepository = socialAuthRepository
    }
    
    func execute() -> SocialAuthType? {
        socialAuthRepository.getSignedInSNSType()
    }
}
