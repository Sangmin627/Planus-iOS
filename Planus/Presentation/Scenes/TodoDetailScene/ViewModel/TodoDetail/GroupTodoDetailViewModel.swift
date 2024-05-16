//
//  GroupTodoDetailViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/07/26.
//

import Foundation
import RxSwift

extension GroupTodoDetailViewModel {
    enum `Type` {
        case new(Date) // currentDate
        case edit(Int) // todoId
        case view(Int) // todoId
        
        var mode: TodoDetailSceneAuthority {
            switch self {
            case .new: return .newPublic
            case .edit: return .editablePublic
            case .view: return .viewable
            }
        }
    }
}

final class GroupTodoDetailViewModel: TodoDetailViewModelable {
    
    struct UseCases {
        let executeWithTokenUseCase: ExecuteWithTokenUseCase
        
        let fetchGroupTodoDetailUseCase: FetchGroupTodoDetailUseCase
        let createGroupTodoUseCase: CreateGroupTodoUseCase
        let updateGroupTodoUseCase: UpdateGroupTodoUseCase
        let deleteGroupTodoUseCase: DeleteGroupTodoUseCase
        
        let fetchGroupCategorysUseCase: FetchGroupCategorysUseCase
    }
    
    struct Actions {
        var showCategorySelect: ((GroupCategorySelectViewModel.Args) -> Void)?
        var dismiss: (() -> Void)?
    }
    
    struct Args {
        let type: `Type`
        let group: GroupName
    }
    
    struct Injectable {
        let actions: Actions
        let args: Args
    }
    
    let useCases: UseCases
    let actions: Actions
    
    private let type: `Type`
    private let group: GroupName
    
    private let bag = DisposeBag()
    
    var categorys: [Category] = []
    var groups: [GroupName] = []
    
    private let todoTitle = BehaviorSubject<String?>(value: nil)
    private let todoCategory = BehaviorSubject<Category?>(value: nil)
    private let todoDayRange = BehaviorSubject<DateRange>(value: DateRange())
    private let todoTime = BehaviorSubject<String?>(value: nil)
    private let todoGroup = BehaviorSubject<GroupName?>(value: nil)
    private let todoMemo = BehaviorSubject<String?>(value: nil)
    
    private let categoryCreated = PublishSubject<Category>()
    private let categorySelected = PublishSubject<Category>()
    private let categoryUpdated = PublishSubject<Category>()
    private let categoryRemovedWithId = PublishSubject<Int>()
    
    private let dismissRequired = PublishSubject<Void>()
    
    private let groupListChanged = PublishSubject<Void>()
    private let showMessage = PublishSubject<Message>()
    private let showSaveConstMessagePopUp = PublishSubject<Void>()
    
    private var nowSaving: Bool = false
    private var isSaveEnabled: Bool?
    
    init(
        useCases: UseCases,
        injectable: Injectable
    ) {
        self.useCases = useCases
        self.actions = injectable.actions
        
        self.type = injectable.args.type
        self.group = injectable.args.group
        self.groups.append(injectable.args.group)
    }
    
    func transform(input: Input) -> Output {
        bind()

        input
            .titleTextChanged
            .bind(to: todoTitle)
            .disposed(by: bag)
        
        input
            .dayRange
            .bind(to: todoDayRange)
            .disposed(by: bag)
        
        input
            .timeFieldChanged
            .bind(to: todoTime)
            .disposed(by: bag)
        
        input
            .groupSelectedAt
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                let group = index.map({ vm.groups[$0] })
                vm.todoGroup.onNext(group)
            })
            .disposed(by: bag)
        
        input
            .memoTextChanged
            .bind(to: todoMemo)
            .disposed(by: bag)
        
        Observable
            .combineLatest(
                todoTitle.asObservable(),
                todoCategory.asObservable(),
                todoDayRange.asObservable()
            )
            .map { (title, category, dayRange) in
                guard let title,
                      let category,
                      let _ = dayRange.start else { return false }
                
                return !title.isEmpty
            }
            .subscribe(onNext: { [weak self] isEnabled in
                self?.isSaveEnabled = isEnabled
            })
            .disposed(by: bag)
        
        input
            .categoryBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.showCategorySelect?(
                    GroupCategorySelectViewModel.Args(
                        categories: vm.categorys,
                        groupId: vm.group.groupId,
                        categorySelected: vm.categorySelected,
                        categoryCreated: vm.categoryCreated,
                        categoryUpdated: vm.categoryUpdated,
                        categoryRemovedWithId: vm.categoryRemovedWithId
                    )
                )
            })
            .disposed(by: bag)
        
        input
            .todoSaveBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                if vm.isSaveEnabled ?? false {
                    if !vm.nowSaving {
                        vm.nowSaving = true
                        vm.saveDetail()
                    }
                } else {
                    vm.showSaveConstMessagePopUp.onNext(())
                }
            })
            .disposed(by: bag)
        
        input
            .todoRemoveBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                if !vm.nowSaving {
                    vm.nowSaving = true
                    vm.removeDetail()
                }
            })
            .disposed(by: bag)
        
        input
            .needDismiss
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.dismiss?()
            })
            .disposed(by: bag)
        
        let groupChangedToIndex = todoGroup
            .distinctUntilChanged()
            .withUnretained(self)
            .map { vm, group -> Int? in
                guard let group else { return nil }
                return vm.groups.firstIndex(of: group)
            }
        
        return Output(
            mode: self.type.mode,
            titleValueChanged: todoTitle.distinctUntilChanged().asObservable(),
            categoryChanged: todoCategory.asObservable(),
            dayRangeChanged: todoDayRange.distinctUntilChanged().asObservable(),
            timeValueChanged: todoTime.distinctUntilChanged().asObservable(),
            groupChangedToIndex: groupChangedToIndex,
            memoValueChanged: todoMemo.distinctUntilChanged().asObservable(),
            showMessage: showMessage.asObservable(),
            showSaveConstMessagePopUp: showSaveConstMessagePopUp.asObservable(),
            dismissRequired: dismissRequired.asObservable()
        )
    }
    
    func fetch() {
        switch type {
        case .new(let date):
            self.todoGroup.onNext(group)
            self.todoDayRange.onNext(DateRange(start: date))
            fetchCategoryList(groupId: group.groupId)
        case .edit(let todoId):
            fetchGroupTodoDetail(groupId: group.groupId, todoId: todoId)
            fetchCategoryList(groupId: group.groupId)
        case .view(let todoId):
            fetchGroupTodoDetail(groupId: group.groupId, todoId: todoId)
        }
    }
}

// MARK: - Initial Fetch
private extension GroupTodoDetailViewModel {
    
    func fetchGroupTodoDetail(groupId: Int, todoId: Int) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchGroupTodoDetailUseCase
                    .execute(token: token, groupId: groupId, todoId: todoId)
            }
            .subscribe(onSuccess: { [weak self] todo in
                self?.todoTitle.onNext(todo.title)
                self?.todoCategory.onNext(Category(id: todo.todoCategory.id, title: todo.todoCategory.name, color: todo.todoCategory.color))
                self?.todoDayRange.onNext(DateRange(start: todo.startDate, end: (todo.startDate != todo.endDate) ? todo.endDate : nil))
                self?.todoTime.onNext(todo.startTime)
                self?.todoGroup.onNext(GroupName(groupId: groupId, groupName: todo.groupName))
                self?.todoMemo.onNext(todo.description)
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.showMessage.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
    
    func fetchCategoryList(groupId: Int) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchGroupCategorysUseCase
                    .execute(token: token, groupId: groupId)
            }
            .subscribe(onSuccess: { [weak self] list in
                self?.categorys = list.filter { $0.status == .active }
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.showMessage.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
}

// MARK: - Button Actions
private extension GroupTodoDetailViewModel {
    func saveDetail() {
        guard let title = try? todoTitle.value(),
              let dateRange = try? todoDayRange.value(),
              let startDate = dateRange.start,
              let categoryId = (try? todoCategory.value())?.id else { return }
        
        var endDate = startDate
        if let todoEndDay = dateRange.end {
            endDate = todoEndDay
        }
        let memo = try? todoMemo.value()
        let time = try? todoTime.value()
        let groupName = try? todoGroup.value()
        var todo = Todo(
            id: nil,
            title: title,
            startDate: startDate,
            endDate: endDate,
            memo: memo,
            groupId: groupName?.groupId,
            categoryId: categoryId,
            startTime: ((time?.isEmpty) ?? true) ? nil : time,
            isCompleted: nil,
            isGroupTodo: false
        )
        
        switch type {
        case .new:
            createTodo(groupId: group.groupId, todo: todo)
        case .edit(let todoId):
            todo.id = todoId
            updateTodo(groupId: group.groupId, todoId: todoId, todo: todo)
        default:
            return
        }
    }
    
    func removeDetail() {
        switch type {
        case .edit(let todoId):
            deleteTodo(groupId: group.groupId, todoId: todoId)
        default:
            return
        }
    }
}

// MARK: - API
private extension GroupTodoDetailViewModel {
    func createTodo(groupId: Int, todo: Todo) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.createGroupTodoUseCase
                    .execute(token: token, groupId: groupId, todo: todo)
            }
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onSuccess: { [weak self] id in
                var todoWithId = todo
                todoWithId.id = id
                self?.nowSaving = false
                self?.dismissRequired.onNext(())
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.nowSaving = false
                self?.showMessage.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
    
    func updateTodo(groupId: Int, todoId: Int, todo: Todo) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.updateGroupTodoUseCase
                    .execute(token: token, groupId: groupId, todoId: todoId, todo: todo)
            }
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onSuccess: { [weak self] _ in
                self?.nowSaving = false
                self?.dismissRequired.onNext(())
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.nowSaving = false
                self?.showMessage.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
    
    func deleteTodo(groupId: Int, todoId: Int) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.deleteGroupTodoUseCase
                    .execute(token: token, groupId: groupId, todoId: todoId)
            }
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onSuccess: { [weak self] _ in
                self?.nowSaving = false
                self?.dismissRequired.onNext(())
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.nowSaving = false
                self?.showMessage.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
}

// MARK: - Bind
private extension GroupTodoDetailViewModel {
    func bind() {
        categorySelected
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                vm.todoCategory.onNext(category)
            })
            .disposed(by: bag)
        
        categoryCreated
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                vm.categorys.append(category)
            })
            .disposed(by: bag)
        
        categoryUpdated
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                guard let index = vm.categorys.firstIndex(where: { $0.id == category.id }) else { return }
                vm.categorys[index] = category
            })
            .disposed(by: bag)
        
        categoryRemovedWithId
            .withUnretained(self)
            .subscribe(onNext: { vm, id in
                vm.categorys.removeAll(where: { $0.id == id })
            })
            .disposed(by: bag)
    }
}
