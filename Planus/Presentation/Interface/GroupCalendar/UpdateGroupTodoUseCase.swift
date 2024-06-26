//
//  UpdateGroupTodoUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/07/26.
//

import Foundation
import RxSwift

protocol UpdateGroupTodoUseCase {
    var didUpdateGroupTodo: PublishSubject<Todo> { get }
    func execute(token: Token, groupId: Int, todoId: Int, todo: Todo) -> Single<Int>
}
