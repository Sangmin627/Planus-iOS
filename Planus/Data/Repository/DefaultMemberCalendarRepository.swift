//
//  DefaultMemberCalendarRepository.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/16.
//

import Foundation
import RxSwift

class DefaultMemberCalendarRepository: MemberCalendarRepository {
    let apiProvider: APIProvider
    
    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }
    
    func fetchMemberTodoList(
        token: String,
        groupId: Int,
        memberId: Int,
        from: Date,
        to: Date
    ) -> Single<ResponseDTO<[TodoEntityResponseDTO]>> {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current
        
        let endPoint = APIEndPoint(
            url: URLPool.myGroup+"/\(groupId)/members/\(memberId)/calendar",
            requestType: .get,
            body: nil,
            query: [
                "from": dateFormatter.string(from: from),
                "to": dateFormatter.string(from: to)
            ],
            header: ["Authorization": "Bearer \(token)"]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<[TodoEntityResponseDTO]>.self
        )
    }
    
    func fetchMemberCategoryList(
        token: String,
        groupId: Int,
        memberId: Int
    ) -> Single<ResponseDTO<[CategoryEntityResponseDTO]>> {
        let endPoint = APIEndPoint(
            url: URLPool.myGroup+"/\(groupId)/members/\(memberId)/categories",
            requestType: .get,
            body: nil,
            query: nil,
            header: ["Authorization": "Bearer \(token)"]
        )
        
        return apiProvider
            .requestCodable(
                endPoint: endPoint,
                type: ResponseDTO<[CategoryEntityResponseDTO]>.self
            )
    }
}
