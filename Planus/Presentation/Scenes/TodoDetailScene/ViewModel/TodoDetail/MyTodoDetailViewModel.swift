//
//  MyTodoDetailViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/28.
//

import Foundation
import RxSwift

extension MyTodoDetailViewModel {
    enum `Type` {
        case new(date: DateRange, group: GroupName?)
        case edit(TodoDetail)
        case view(TodoDetail)
        
        var mode: TodoDetailSceneAuthority {
            switch self {
            case .new: return .newPrivate
            case .edit: return .editablePrivate
            case .view: return .viewable
            }
        }
    }
}

final class MyTodoDetailViewModel: TodoDetailViewModelable {
        
    struct UseCases {
        let executeWithTokenUseCase: ExecuteWithTokenUseCase
        
        let createTodoUseCase: CreateTodoUseCase
        let updateTodoUseCase: UpdateTodoUseCase
        let deleteTodoUseCase: DeleteTodoUseCase
        
        let readCategoryUseCase: ReadCategoryListUseCase
    }
    
    struct Actions {
        var showCategorySelect: ((MyCategorySelectViewModel.Args) -> Void)?
        var dismiss: (() -> Void)?
    }
    
    struct Args {
        let groupList: [GroupName]
        let type: `Type`
    }
    
    struct Injectable {
        let actions: Actions
        let args: Args
    }
    
    let useCases: UseCases
    let actions: Actions
    
    private let type: `Type`
    
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
    
    init(useCases: UseCases, injectable: Injectable) {
        self.useCases = useCases
        self.actions = injectable.actions
        
        self.type = injectable.args.type
        
        self.groups = injectable.args.groupList
        
        switch injectable.args.type {
        case .new(let dateRange, let group):
            self.todoDayRange.onNext(DateRange(start: dateRange.start, end: (dateRange.start != dateRange.end) ? dateRange.end : nil))
            self.todoGroup.onNext(group)
        case .edit(let todoDetail), .view(let todoDetail):
            self.todoGroup.onNext(todoDetail.group)
            self.todoCategory.onNext(todoDetail.category)
            self.todoTitle.onNext(todoDetail.title)
            self.todoDayRange.onNext(DateRange(start: todoDetail.startDate, end: (todoDetail.startDate != todoDetail.endDate) ? todoDetail.endDate : nil))
            self.todoTime.onNext(todoDetail.startTime)
            self.todoMemo.onNext(todoDetail.memo)
        }
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
                    MyCategorySelectViewModel.Args(
                        categories: vm.categorys,
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
            groupChangedToIndex: groupChangedToIndex.asObservable(),
            memoValueChanged: todoMemo.distinctUntilChanged().asObservable(),
            showMessage: showMessage.asObservable(),
            showSaveConstMessagePopUp: showSaveConstMessagePopUp.asObservable(),
            dismissRequired: dismissRequired.asObservable()
        )
    }
    
    func fetch() {
        fetchCategoryList()
    }
}

// MARK: - Initail Fetch
private extension MyTodoDetailViewModel {
    
    func fetchCategoryList() {
        useCases.executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.readCategoryUseCase
                    .execute(token: token)
            }
            .subscribe(onSuccess: { [weak self] list in
                self?.categorys = list.filter { $0.status == .active }
            })
            .disposed(by: bag)
    }
}

// MARK: - Button Actions
private extension MyTodoDetailViewModel {
    func saveDetail() {
        guard let title = try? todoTitle.value(),
              let dayRange = try? todoDayRange.value(),
              let startDate = dayRange.start,
              let categoryId = (try? todoCategory.value())?.id else { return }
        
        var endDate = startDate
        if let todoEndDay = dayRange.end {
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
            memo: (memo?.isEmpty ?? true) ? nil : memo,
            groupId: groupName?.groupId,
            categoryId: categoryId,
            startTime: ((time?.isEmpty) ?? true) ? nil : time,
            isCompleted: nil,
            isGroupTodo: false
        )
        
        
        switch type {
        case .new:
            createTodo(todo: todo)
        case .edit(let oldValue):
            todo.id = oldValue.id
            todo.isCompleted = oldValue.isCompleted
            todo.isGroupTodo = oldValue.isGroupTodo
            updateTodo(todoUpdate: TodoUpdateComparator(before: oldValue.toTodo(), after: todo))
        default:
            return
        }
    }
    
    func removeDetail() {
        switch type {
        case .edit(let oldValue):
            deleteTodo(todo: oldValue.toTodo())
        default:
            return
        }
    }
}

// MARK: - API
private extension MyTodoDetailViewModel {
    func createTodo(todo: Todo) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.createTodoUseCase
                    .execute(token: token, todo: todo)
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
                self?.showMessage.onNext(Message(text: message, state: .warning))
                self?.nowSaving = false
            })
            .disposed(by: bag)
    }
    
    func updateTodo(todoUpdate: TodoUpdateComparator) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.updateTodoUseCase
                    .execute(token: token, todoUpdate: todoUpdate)
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
    
    func deleteTodo(todo: Todo) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.deleteTodoUseCase
                    .execute(token: token, todo: todo)
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

// MARK: - bind
private extension MyTodoDetailViewModel {
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
