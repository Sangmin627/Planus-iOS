//
//  DefaultGroupRepository.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/09.
//

import Foundation
import RxSwift

class DefaultGroupRepository: GroupRepository {
    let apiProvider: APIProvider
    
    init(apiProvider: APIProvider) {
        self.apiProvider = apiProvider
    }
    
    func fetchGroupDetail(token: String, id: Int) -> Single<ResponseDTO<UnJoinedGroupDetailResponseDTO>> {
        let endPoint = APIEndPoint(
            url: URLPool.groups + "/\(id)",
            requestType: .get,
            body: nil,
            query: nil,
            header: ["Authorization": "Bearer \(token)"]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<UnJoinedGroupDetailResponseDTO>.self
        )
    }
    
    func fetchMemberList(token: String, id: Int) -> Single<ResponseDTO<[MemberDTO]>> {
        let endPoint = APIEndPoint(
            url: URLPool.groups + "/\(id)/members",
            requestType: .get,
            body: nil,
            query: nil,
            header: ["Authorization": "Bearer \(token)"]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<[MemberDTO]>.self
        )
    }
    
    func joinGroup(token: String, id: Int) -> Single<ResponseDTO<GroupJoinApplingResponseDTO>> {
        let endPoint = APIEndPoint(
            url: URLPool.groups + "/\(id)/joins",
            requestType: .post,
            body: nil,
            query: nil,
            header: ["Authorization": "Bearer \(token)"]
        )
        
        return apiProvider.requestCodable(
            endPoint: endPoint,
            type: ResponseDTO<GroupJoinApplingResponseDTO>.self
        )
    }
}
