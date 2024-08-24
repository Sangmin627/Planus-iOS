//
//  DefaultFCMRepository.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/09/07.
//

import Foundation
import RxSwift

final class DefaultFCMRepository: FCMRepository {
    private let apiProvider: APIProvider
    private let keyValueStorage: PersistantKeyValueStorage
    
    init(apiProvider: APIProvider, keyValueStorage: PersistantKeyValueStorage) {
        self.apiProvider = apiProvider
        self.keyValueStorage = keyValueStorage
    }
    
    func patchFCMToken(token: String) -> Single<ResponseDTO<FCMTokenResponseDTO>> {
        let fcm = keyValueStorage.get(key: "fcmToken") as! String
        let dto = FCMTokenRequestDTO(fcmToken: fcm)
        
        let endPoint = APIEndPoint(
            url: BaseURL.main() + URLPathComponent.app + "/fcm-token",
            requestType: .patch,
            body: dto,
            query: nil,
            header: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]
        )
        
        return apiProvider.request(
            endPoint: endPoint,
            type: ResponseDTO<FCMTokenResponseDTO>.self
        )
    }
}
