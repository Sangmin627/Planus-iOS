//
//  TodoDetailViewModelable.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/07/26.
//

import Foundation
import RxSwift

enum TodoDetailSceneAuthority {
    // 개인과 공용의 차이 (그룹 변경 가능 여부)
    case newPrivate
    case editablePrivate
    case newPublic
    case editablePublic
    case viewable
}

struct TodoDetailViewModelableInput {
    // MARK: Control Value
    var titleTextChanged: Observable<String?>
    var dayRange: Observable<DateRange>
    var timeFieldChanged: Observable<String?>
    var groupSelectedAt: Observable<Int?>
    var memoTextChanged: Observable<String?>
    
    // MARK: Control Event
    var categoryBtnTapped: Observable<Void>
    var todoSaveBtnTapped: Observable<Void>
    var todoRemoveBtnTapped: Observable<Void>
    var needDismiss: Observable<Void>
}

struct TodoDetailViewModelableOutput {
    var mode: TodoDetailSceneAuthority
    var titleValueChanged: Observable<String?>
    var categoryChanged: Observable<Category?>
    var dayRangeChanged: Observable<DateRange>
    var timeValueChanged: Observable<String?>
    var groupChangedToIndex: Observable<Int?>
    var memoValueChanged: Observable<String?>
    var showMessage: Observable<Message>
    var showSaveConstMessagePopUp: Observable<Void>
    var dismissRequired: Observable<Void>
}

protocol TodoDetailViewModelable: AnyObject, ViewModelable {
    typealias Input = TodoDetailViewModelableInput
    typealias Output = TodoDetailViewModelableOutput
    
    var groups: [GroupName] { get set }
    
    func fetch()
}
