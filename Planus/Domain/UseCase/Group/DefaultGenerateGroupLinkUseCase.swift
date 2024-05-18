//
//  DefaultGenerateGroupLinkUseCase.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/30.
//

import Foundation

final class DefaultGenerateGroupLinkUseCase: GenerateGroupLinkUseCase {
    func execute(groupId: Int) -> String {
        return "\(BaseURL.main)\(URLPathComponent.groups)?groupID=\(groupId)"
    }
}
