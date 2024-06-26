//
//  UpdateGroupInfoUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/15.
//

import Foundation
import RxSwift

protocol UpdateGroupInfoUseCase {
    var didUpdateInfoWithId: PublishSubject<Int> { get }
    func execute(
        token: Token,
        groupId: Int,
        tagList: [String],
        limit: Int,
        image: ImageFile
    ) -> Single<Void>
}
