//
//  UpdateTodoCategoryUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/27.
//

import Foundation
import RxSwift

protocol UpdateCategoryUseCase {
    var didUpdateCategory: PublishSubject<Category> { get }
    func execute(token: Token, category: Category) -> Single<Int>
}
