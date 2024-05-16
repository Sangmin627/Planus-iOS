//
//  MyDailyCalendarViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/06.
//

import Foundation
import RxSwift

final class MyDailyCalendarViewModel: DailyCalendarViewModelable {
    
    struct UseCases {
        let executeWithTokenUseCase: ExecuteWithTokenUseCase
        
        let createTodoUseCase: CreateTodoUseCase
        let updateTodoUseCase: UpdateTodoUseCase
        let deleteTodoUseCase: DeleteTodoUseCase
        
        let todoCompleteUseCase: TodoCompleteUseCase
        
        let createCategoryUseCase: CreateCategoryUseCase
        let updateCategoryUseCase: UpdateCategoryUseCase
        let deleteCategoryUseCase: DeleteCategoryUseCase
        let readCategoryUseCase: ReadCategoryListUseCase
    }
    
    struct Actions {
        var showTodoDetailPage: ((MyTodoDetailViewModel.Args, (() -> Void)?) -> Void)?
        var finishScene: (() -> Void)?
    }
    
    struct Args {
        let currentDate: Date
        let todoList: [Todo]
        let categoryDict: [Int: Category]
        let groupDict: [Int: GroupName]
        let groupCategoryDict: [Int: Category]
        let filteringGroupId: Int?
    }
    
    struct Injectable {
        let actions: Actions
        let args: Args
    }
    
    private let bag = DisposeBag()
    let useCases: UseCases
    let actions: Actions

    private var todos: [[Todo]] = [[Todo]](repeating: [Todo](), count: DailyCalendarTodoType.allCases.count)
    private var categoryDict: [Int: Category] = [:]
    private var groupCategoryDict: [Int: Category] = [:]
    private var groupDict: [Int: GroupName] = [:]
    
    // MARK: - ViewModel
    var todoViewModels = [[TodoDailyViewModel]](repeating: [TodoDailyViewModel](), count: DailyCalendarTodoType.allCases.count)
    
    private var filteringGroupId: Int?

    private var currentDate: Date?
    private var currentDateText: String?
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 MM월 dd일"
        return dateFormatter
    }()
    
    private let needInsertItem = PublishSubject<IndexPath>()
    private let needDeleteItem = PublishSubject<IndexPath>()
    private let needReloadData = PublishSubject<Void?>()
    private let needUpdateItem = PublishSubject<(removed: IndexPath, created: IndexPath)>()
    private let showAlert = PublishSubject<Message>()
    

    init(
        useCases: UseCases,
        injectable: Injectable
    ) {
        self.useCases = useCases
        self.actions = injectable.actions
        
        setDate(currentDate: injectable.args.currentDate)
        setCategoryAndGroup(
            categoryDict: injectable.args.categoryDict,
            groupDict: injectable.args.groupDict,
            groupCategoryDict: injectable.args.groupCategoryDict,
            filteringGroupId: injectable.args.filteringGroupId
        )
        setTodoListSorted(todoList: injectable.args.todoList)
    }
    
    func transform(input: Input) -> Output {
        bindTodoUseCase()
        bindCategoryUseCase()
        
        input
            .addTodoTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                let groupList = vm.groupDict.values.sorted { $0.groupId < $1.groupId }
                let groupName = vm.filteringGroupId.flatMap { vm.groupDict[$0] }
                
                vm.actions.showTodoDetailPage?(
                    MyTodoDetailViewModel.Args(
                        groupList: groupList,
                        type: .new(date: DateRange(start: vm.currentDate, end: nil), group: groupName)
                    ),
                    nil
                )
            })
            .disposed(by: bag)
        
        input
            .todoSelectedAt
            .withUnretained(self)
            .subscribe(onNext: { vm, indexPath in
                vm.todoItemSelected(at: indexPath)
            })
            .disposed(by: bag)
        
        input
            .completeTodoAt
            .withUnretained(self)
            .subscribe(onNext: { vm, indexPath in
                vm.completeTodoDataAt(indexPath: indexPath)
            })
            .disposed(by: bag)
        
        input
            .viewDidDismissed
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.finishScene?()
            })
            .disposed(by: bag)
        
        return Output(
            currentDateText: currentDateText,
            needInsertItem: needInsertItem.asObservable(),
            needDeleteItem: needDeleteItem.asObservable(),
            needReloadData: needReloadData.asObservable(),
            needUpdateItem: needUpdateItem.asObservable(),
            showAlert: showAlert.asObservable(),
            mode: .interactable
        )        
    }
}

// MARK: bind useCase
private extension MyDailyCalendarViewModel {
    func bindTodoUseCase() {
        useCases.createTodoUseCase
            .didCreateTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                vm.notifiedTodoCreated(todo: todo)
            })
            .disposed(by: bag)
        
        useCases.updateTodoUseCase
            .didUpdateTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todoUpdate in
                vm.notifiedTodoUpdated(before: todoUpdate.before, after: todoUpdate.after)
            })
            .disposed(by: bag)
        
        useCases.deleteTodoUseCase
            .didDeleteTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                vm.notifiedTodoRemoved(todo: todo)
            })
            .disposed(by: bag)
    }
    
    func bindCategoryUseCase() {
        useCases.createCategoryUseCase
            .didCreateCategory
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                guard let id = category.id else { return }
                
                vm.categoryDict[id] = category
            })
            .disposed(by: bag)
        
        useCases.updateCategoryUseCase
            .didUpdateCategory
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                guard let id = category.id else { return }
                vm.categoryDict[id] = category
                
                let indexPaths = vm.todos.enumerated().flatMap { (section, todoList) in
                    todoList.enumerated().map { (item, todo) in
                        IndexPath(item: item, section: section)
                    }
                }
                vm.updateViewModel(at: indexPaths)
                vm.needReloadData.onNext(())
            })
            .disposed(by: bag)
        
    }
}

// MARK: - settings
private extension MyDailyCalendarViewModel {
    func setDate(currentDate: Date) {
        self.currentDate = currentDate
        self.currentDateText = dateFormatter.string(from: currentDate)
    }
    
    func setCategoryAndGroup(
        categoryDict: [Int: Category],
        groupDict: [Int: GroupName],
        groupCategoryDict: [Int: Category],
        filteringGroupId: Int?
    ) {
        self.categoryDict = categoryDict
        self.groupCategoryDict = groupCategoryDict
        self.groupDict = groupDict
        self.filteringGroupId = filteringGroupId
    }
    
    private func setTodoListSorted(todoList: [Todo]) {
        // 필터링 그룹 ID에 따라 투두 필터링
        let filteredTodoList = todoList.filter { todo in
            guard let filteringGroupId = filteringGroupId else { return true }
            return todo.groupId == filteringGroupId
        }
        
        // 일정과 투두를 분리
        let scheduledTodos = filteredTodoList.filter { $0.startTime != nil }
        let unscheduledTodos = filteredTodoList.filter { $0.startTime == nil }
        
        // 정렬 방식 정의
        let timeComparator: ((Todo, Todo) -> Bool) = { $0.startTime ?? "" < $1.startTime ?? "" }
        let idComparator: ((Todo, Todo) -> Bool) = { $0.id ?? 0 < $1.id ?? 0 }
        
        let sortedScheduledTodos = scheduledTodos.sorted(by: timeComparator)
        let sortedUnscheduledTodos = unscheduledTodos.sorted(by: idComparator)
        
        // 정렬된 할 일 목록을 설정합니다.
        self.todos[DailyCalendarTodoType.scheduled.rawValue] = sortedScheduledTodos
        self.todos[DailyCalendarTodoType.unscheduled.rawValue] = sortedUnscheduledTodos
        
        // 뷰모델 생성
        let indexPaths = todos.enumerated().flatMap { (section, todoList) in
            todoList.enumerated().map { (item, todo) in
                IndexPath(item: item, section: section)
            }
        }
        createViewModel(at: indexPaths)
    }
}

// MARK: - prepare ViewModel
extension MyDailyCalendarViewModel {
    func createViewModel(at indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            let todo = self.todos[indexPath.section][indexPath.item]
            let category = todo.isGroupTodo ? self.groupCategoryDict[todo.categoryId] : self.categoryDict[todo.categoryId]
            self.todoViewModels[indexPath.section].insert(todo.toDailyViewModel(color: category?.color ?? .none), at: indexPath.item)
        }
    }
    
    func updateViewModel(at indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            let todo = self.todos[indexPath.section][indexPath.item]
            let category = todo.isGroupTodo ? self.groupCategoryDict[todo.categoryId] : self.categoryDict[todo.categoryId]
            self.todoViewModels[indexPath.section][indexPath.row] = todo.toDailyViewModel(color: category?.color ?? .none)
        }
    }
    
    func removeViewModel(at indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            self.todoViewModels[indexPath.section].remove(at: indexPath.item)
        }
    }
}

// MARK: Notified from UseCases
private extension MyDailyCalendarViewModel {
    func notifiedTodoCreated(todo: Todo) {
        guard let currentDate,
              todo.startDate <= currentDate,
              currentDate <= todo.endDate else { return }
        
        if let filteringGroupId = filteringGroupId,
           todo.groupId != filteringGroupId {
            return
        }
        
        let indexPath = createTodoData(todo: todo)
        createViewModel(at: [indexPath])
        needInsertItem.onNext(indexPath)
    }
    
    func notifiedTodoRemoved(todo: Todo) {
        let indexPath = removeTodoData(todo: todo)
        removeViewModel(at: [indexPath])
        needDeleteItem.onNext(indexPath)
    }
    
    func notifiedTodoUpdated(before: Todo, after: Todo) {
        guard let currentDate else { return }
        
        if after.startDate > currentDate || after.endDate < currentDate { //날짜 변경 시 제거
            let removedIndexPath = removeTodoData(todo: before)
            removeViewModel(at: [removedIndexPath])
            needDeleteItem.onNext(removedIndexPath)
        }
        else if let filteringGroupId = filteringGroupId,
                after.groupId != filteringGroupId { //그룹 필터링 중에 그룹이 바뀐 경우 제거
            let removedIndexPath = removeTodoData(todo: before)
            removeViewModel(at: [removedIndexPath])
            needDeleteItem.onNext(removedIndexPath)
        } else {
            let removedIndexPath = removeTodoData(todo: before)
            let createdIndexPath = createTodoData(todo: after)
            removeViewModel(at: [removedIndexPath])
            createViewModel(at: [createdIndexPath])
            needUpdateItem.onNext((removed: removedIndexPath, created: createdIndexPath))
        }
    }
}

// MARK: - Todo Model Actions
private extension MyDailyCalendarViewModel {
    func createTodoData(todo: Todo) -> IndexPath {
        let section = todo.startTime != nil ? DailyCalendarTodoType.scheduled.rawValue : DailyCalendarTodoType.unscheduled.rawValue

        let memberTodoList = todos[section].enumerated().filter { !$1.isGroupTodo }
        let innerIndex = memberTodoList.insertionIndexOf(
            (Int(), todo),
            isOrderedBefore: { $0.1.startTime ?? String() < $1.1.startTime ?? String() }
         )
        
        let item = innerIndex == memberTodoList.count ? todos[section].count : memberTodoList[innerIndex].0
        todos[section].insert(todo, at: item)

        return IndexPath(item: item, section: section)
    }
    
    func removeTodoData(todo: Todo) -> IndexPath {
        let section = todo.startTime != nil ? DailyCalendarTodoType.scheduled.rawValue : DailyCalendarTodoType.unscheduled.rawValue
        let item = todos[section].firstIndex(where: { $0.id == todo.id && !$0.isGroupTodo}) ?? 0
        todos[section].remove(at: item)

        return IndexPath(item: item, section: section)
    }
    
    func completeTodoDataAt(indexPath: IndexPath) {
        var todo = todos[indexPath.section][indexPath.item]
        guard var isCompleted = todo.isCompleted else { return }
        
        isCompleted = !isCompleted
        todo.isCompleted = isCompleted
        todos[indexPath.section][indexPath.item] = todo
        
        updateViewModel(at: [indexPath])
        sendCompletionState(todo: todo)
    }
}

// MARK: - UI Actions
private extension MyDailyCalendarViewModel {
    func todoItemSelected(at indexPath: IndexPath) {
        guard !todos[indexPath.section].isEmpty else { return }
        let item = todos[indexPath.section][indexPath.item]
        let todoDetail = item.toDetail(groups: groupDict, categories: item.isGroupTodo ? groupCategoryDict : categoryDict)

        let groupList = Array(groupDict.values).sorted(by: { $0.groupId < $1.groupId })
        
        var type: MyTodoDetailViewModel.`Type`
        if item.isGroupTodo {
            type = .view(todoDetail)
        } else {
            type = .edit(todoDetail)
        }

        actions.showTodoDetailPage?(
            MyTodoDetailViewModel.Args(
                groupList: groupList,
                type: type
            ),
            nil
        )
    }
}

// MARK: API
private extension MyDailyCalendarViewModel {
    func sendCompletionState(todo: Todo) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.todoCompleteUseCase
                    .execute(token: token, todo: todo)
            }
            .subscribe(onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(_, let message) = error,
                      let message = message else { return }
                self?.showAlert.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
}
