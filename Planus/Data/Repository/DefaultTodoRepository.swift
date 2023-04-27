//
//  DefaultTodoRepository.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/23.
//

import Foundation
import RxSwift

class TestTodoDetailRepository: TodoRepository {
    
    let apiProvider: APIProvider
    
    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }
    
    func createTodo(token: String, todo: TodoRequestDTO) -> Single<Int> {
        let endPoint = APIEndPoint(
            url: "localhost:8080/app/todos",
            requestType: .post,
            body: todo,
            query: nil,
            header: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<TodoResponseDataDTO>.self
        )
        .map {
            $0.data.todoId
        }
    }
    
    func readTodo(token: String, from: Date, to: Date) -> Single<ResponseDTO<[TodoEntityResponseDTO]>> { //어케올지 모름!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current
        
        let endPoint = APIEndPoint(
            url: "localhost:8080/app/todos",
            requestType: .get,
            body: nil,
            query: [
                "from": dateFormatter.string(from: from),
                "to": dateFormatter.string(from: to)
            ],
            header: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<[TodoEntityResponseDTO]>.self
        )
    }
    
    func updateTodo(token: String, id: Int, todo: TodoRequestDTO) -> Single<Int> {
        let endPoint = APIEndPoint(
            url: "localhost:8080/app/todos/\(id)",
            requestType: .patch,
            body: todo,
            query: nil,
            header: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<TodoResponseDataDTO>.self
        )
        .map {
            $0.data.todoId
        }
    }
    
    func deleteTodo(token: String, id: Int) -> Single<Void> {
        let endPoint = APIEndPoint(
            url: "localhost:8080/app/todos/\(id)",
            requestType: .delete,
            body: nil,
            query: nil,
            header: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<TodoResponseDataDTO>.self
        )
        .map { _ in
            return ()
        }
    }
}
