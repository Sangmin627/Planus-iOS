//
//  DefaultSetOnlineUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/10.
//

import Foundation
import RxSwift

class DefaultSetOnlineUseCase: SetOnlineUseCase {
    let myGroupRepository: MyGroupRepository
    
    var didChangeOnlineState = PublishSubject<Int>()
    
    init(myGroupRepository: MyGroupRepository) {
        self.myGroupRepository = myGroupRepository
    }
    
    func execute(token: Token, groupId: Int) -> Single<Void> {
        myGroupRepository
            .changeOnlineState(token: token.accessToken, groupId: groupId)
            .map { _ in () }
    }
}
