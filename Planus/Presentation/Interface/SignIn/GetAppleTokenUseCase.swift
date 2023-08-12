//
//  GetAppleTokenUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/12.
//

import Foundation
import RxSwift

protocol GetAppleTokenUseCase {
    func execute(authorizationCode: String) -> Single<Token>
}
