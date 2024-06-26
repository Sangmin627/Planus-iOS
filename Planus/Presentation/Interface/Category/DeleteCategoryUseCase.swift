//
//  DeleteTodoCategoryUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/27.
//

import Foundation
import RxSwift

protocol DeleteCategoryUseCase {
    var didDeleteCategory: PublishSubject<Int> { get }
    func execute(token: Token, id: Int) -> Single<Void>
}
