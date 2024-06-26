//
//  DefaultUpdateGroupInfoUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/15.
//

import Foundation
import RxSwift

final class DefaultUpdateGroupInfoUseCase: UpdateGroupInfoUseCase {

    private let myGroupRepository: MyGroupRepository
    let didUpdateInfoWithId = PublishSubject<Int>()
    
    init(myGroupRepository: MyGroupRepository) {
        self.myGroupRepository = myGroupRepository
    }
    
    func execute(
        token: Token,
        groupId: Int,
        tagList: [String],
        limit: Int,
        image: ImageFile
    ) -> Single<Void> {
        return myGroupRepository
            .updateInfo(
                token: token.accessToken,
                groupId: groupId,
                editRequestDTO: MyGroupInfoEditRequestDTO(tagList: tagList.map { GroupTagRequestDTO(name: $0) }, limitCount: limit),
                image: image
            )
            .do(onSuccess: { [weak self] _ in
                self?.didUpdateInfoWithId.onNext(groupId)
            })
            .map { _ in
                return ()
            }
    }
}
