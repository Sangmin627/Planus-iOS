//
//  HomeCalendarViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/23.
//

import Foundation
import RxSwift

extension HomeCalendarViewModel {
    enum CalendarMovable {
        case scroll(Int)
        case jump(Int)
        case initialized(Int)
    }

    enum SectionChange {
        case apiFetched(IndexSet)
        case internalChange(IndexSet)
    }
}

final class HomeCalendarViewModel: ViewModelable {
    
    struct UseCases {
        let executeWithTokenUseCase: ExecuteWithTokenUseCase
        
        let createTodoUseCase: CreateTodoUseCase
        let readTodoListUseCase: ReadTodoListUseCase
        let updateTodoUseCase: UpdateTodoUseCase
        let deleteTodoUseCase: DeleteTodoUseCase
        let todoCompleteUseCase: TodoCompleteUseCase
        
        let createCategoryUseCase: CreateCategoryUseCase
        let readCategoryListUseCase: ReadCategoryListUseCase
        let updateCategoryUseCase: UpdateCategoryUseCase
        let deleteCategoryUseCase: DeleteCategoryUseCase
        let fetchGroupCategoryListUseCase: FetchAllGroupCategoryListUseCase
        
        let fetchMyGroupNameListUseCase: FetchMyGroupNameListUseCase
        let groupCreateUseCase: GroupCreateUseCase
        let withdrawGroupUseCase: WithdrawGroupUseCase
        let deleteGroupUseCase: DeleteGroupUseCase
        
        let createMonthlyCalendarUseCase: CreateMonthlyCalendarUseCase
        let dateFormatYYYYMMUseCase: DateFormatYYYYMMUseCase
        
        let readProfileUseCase: ReadProfileUseCase
        let updateProfileUseCase: UpdateProfileUseCase
        let fetchImageUseCase: FetchImageUseCase
    }
    
    struct Actions {
        var showDailyCalendarPage: ((MyDailyCalendarViewModel.Args) -> Void)?
        var showCreatePeriodTodoPage: ((MyTodoDetailViewModel.Args, (() -> Void)?) -> Void)?
        var showMyPage: ((Profile) -> Void)?
    }
    
    struct Args {}
    
    struct Injectable {
        let actions: Actions
        let args: Args
    }
    
    private let bag = DisposeBag()
    
    let useCases: UseCases
    let actions: Actions
    
    private let cachingIndexDiff = 8
    private let cachingAmount = 10
    private let endOfFirstIndex = -100
    private let endOfLastIndex = 100
    
    private var prevBufferRequestedIndex = 0
    private var followingBufferRequestedIndex = 0
    
    let today: Date
    private let firstMonth: Date
    
    private let currentMonth = BehaviorSubject<Date?>(value: nil)
    private let dateTitle = BehaviorSubject<String?>(value: nil)

    private var todos = [Date: [Todo]]()
    
    // MARK: - Used as Calendar DataSource
    var mainDays = [[Day]]()
    var dailyViewModels = [Date: DailyViewModel]()
    
    // MARK: - UI Generating Buffer
    private var todoStackingBuffer = [[Bool]](repeating: [Bool](repeating: false, count: 30), count: 42)
    var cachedCellHeightForTodoCount = [Int: Double]()
    
    private var currentIndex = BehaviorSubject<Int>(value: 0)
    private let filteredGroupId = BehaviorSubject<Int?>(value: nil)
    
    private var groups = [Int: GroupName]()
    private var memberCategories = [Int: Category]()
    private var groupCategories = [Int: Category]()
    
    var profile: Profile?
    
    private var nowRefreshing: Bool = false
    private let refreshFinished = PublishSubject<Void>()
    private let showMonthPicker = PublishSubject<(first: Date, current: Date, last: Date)>()
    private let reloadSectionSet = PublishSubject<SectionChange>()
    private let needMoveToIndex = BehaviorSubject<CalendarMovable?>(value: nil)
    private let showAlert = PublishSubject<Message>()
    private let fetchedProfileImage = BehaviorSubject<Data?>(value: nil)
    private let groupListFetched = BehaviorSubject<[GroupName]?>(value: nil)
    private var createPeriodTodoCompletionHandler: ((IndexPath) -> Void)?

    struct Input {
        var viewDidLoaded: Observable<Void>
        var movedToIndex: Observable<CalendarMovable>
        var itemSelectedAt: Observable<IndexPath>
        var multipleItemSelectedInRange: Observable<(IndexPath, IndexPath)>
        var titleBtnTapped: Observable<Void>
        var monthSelected: Observable<Date>
        var filterGroupWithId: Observable<Int?>
        var refreshRequired: Observable<Void>
        var profileBtnTapped: Observable<Void>
        var createPeriodTodoCompletionHandler: ((IndexPath) -> Void)?
    }
    
    struct Output {
        var dateTitleUpdated: Observable<String?>
        var needMoveTo: Observable<CalendarMovable?>
        var showMonthPicker: Observable<(first: Date, current: Date, last: Date)>
        var reloadSectionSet: Observable<SectionChange>
        var profileImageFetched: Observable<Data?>
        var groupListFetched: Observable<[GroupName]?>
        var didFinishRefreshing: Observable<Void>
        var showAlert: Observable<Message>
    }
        
    init(
        useCases: UseCases,
        injectable: Injectable
    ) {
        self.useCases = useCases
        self.actions = injectable.actions
        
        self.today = sharedCalendar.startOfDay(date: Date())
        self.firstMonth = sharedCalendar.date(
            byAdding: .month,
            value: self.endOfFirstIndex,
            to: sharedCalendar.startDayOfMonth(date: self.today)
        ) ?? Date()
    }
    
    func transform(input: Input) -> Output {
        input.viewDidLoaded
            .withUnretained(self)
            .subscribe { vm, _ in
                vm.fetchProfile()
                vm.initCalendar()
                vm.bind()
            }
            .disposed(by: bag)
        
        input
            .movedToIndex
            .withUnretained(self)
            .subscribe { vm, type in
                switch type {
                case .scroll(let index):
                    vm.scrolledTo(index: index)
                case .jump(let index), .initialized(let index):
                    vm.jumpedTo(index: index)
                }
            }
            .disposed(by: bag)
        
        input
            .itemSelectedAt
            .withUnretained(self)
            .subscribe { vm, indexPath in
                let day = vm.mainDays[indexPath.section][indexPath.item]
                vm.actions.showDailyCalendarPage?(MyDailyCalendarViewModel.Args(
                    currentDate: day.date,
                    todoList: vm.todos[day.date] ?? [],
                    categoryDict: vm.memberCategories ,
                    groupDict: vm.groups ,
                    groupCategoryDict: vm.groupCategories ,
                    filteringGroupId: try? vm.filteredGroupId.value()
                ))
            }
            .disposed(by: bag)
        
        input
            .multipleItemSelectedInRange
            .withUnretained(self)
            .subscribe { vm, range in
                let (firstIndexPath, lastIndexPath) = range
                vm.multipleDaysSelected(firstIndexPath, lastIndexPath)
            }
            .disposed(by: bag)
        
        input
            .titleBtnTapped
            .withUnretained(self)
            .subscribe { vm, _ in
                guard let currentDate = try? vm.currentMonth.value() else { return }
                let first = vm.firstMonth
                let last = sharedCalendar.date(byAdding: .month, value: vm.endOfLastIndex - vm.endOfFirstIndex, to: first)!
                vm.showMonthPicker.onNext((first: first, current: currentDate, last: last))
            }
            .disposed(by: bag)
        
        input
            .monthSelected
            .withUnretained(self)
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { vm, date in
                let index = vm.indexOfMonth(date)
                vm.needMoveToIndex.onNext(.jump(index))
            })
            .disposed(by: bag)
        
        input
            .filterGroupWithId
            .withUnretained(self)
            .subscribe(onNext: { vm, groupId in
                vm.filteredGroupId.onNext(groupId)
                vm.reDrawDailyViewModel()
            })
            .disposed(by: bag)
                
        input
            .refreshRequired
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.nowRefreshing = true
                vm.fetchAll()
            })
            .disposed(by: bag)
        
        input
            .profileBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                guard let profile = vm.profile else { return }
                vm.actions.showMyPage?(profile)
            })
            .disposed(by: bag)
        
        self.createPeriodTodoCompletionHandler = input.createPeriodTodoCompletionHandler
        
        return Output(
            dateTitleUpdated: dateTitle.asObservable(),
            needMoveTo: needMoveToIndex.asObservable(),
            showMonthPicker: showMonthPicker.asObservable(),
            reloadSectionSet: reloadSectionSet,
            profileImageFetched: fetchedProfileImage.asObservable(),
            groupListFetched: groupListFetched.asObservable(),
            didFinishRefreshing: refreshFinished.asObservable(),
            showAlert: showAlert.asObservable()
        )
    }
}

// MARK: - Calendar Initializer
private extension HomeCalendarViewModel {
    func initCalendar() {
        mainDays = (0...endOfLastIndex - endOfFirstIndex).map { diff -> [Day] in
            let calendarDate = sharedCalendar.date(byAdding: DateComponents(month: diff), to: firstMonth) ?? Date()
            return useCases.createMonthlyCalendarUseCase.execute(date: calendarDate)
        }
        
        let center = -endOfFirstIndex
        needMoveToIndex.onNext(.initialized(center))
    }
    
    func initTodoList() {
        guard let currentIndex = try? currentIndex.value() else { return }
        prevBufferRequestedIndex = currentIndex
        followingBufferRequestedIndex = currentIndex
        let firstIndex = max(currentIndex - cachingAmount, 0)
        let lastIndex = min(currentIndex + cachingAmount + 1, mainDays.count-1)
                
        todos.removeAll()
        dailyViewModels.removeAll()
        
        fetchTodoList(from: firstIndex, to: lastIndex)
    }
}

// MARK: Calendar Actions
private extension HomeCalendarViewModel {
    func scrolledTo(index: Int) {
        currentIndex.onNext(index)
        checkCacheLoadNeed(currentIndex: index)
    }
    
    func jumpedTo(index: Int) {
        currentIndex.onNext(index)
        fetchAll()
    }
    
    func checkCacheLoadNeed(currentIndex: Int) {
        if prevBufferRequestedIndex - currentIndex == cachingIndexDiff {
            prevBufferRequestedIndex = currentIndex
            let fromIndex = currentIndex - cachingAmount
            let toIndex = currentIndex - (cachingAmount - cachingIndexDiff)
            fetchTodoList(from: fromIndex, to: toIndex)
        } else if currentIndex - followingBufferRequestedIndex == cachingIndexDiff {
            followingBufferRequestedIndex = currentIndex
            let fromIndex = currentIndex + cachingAmount - cachingIndexDiff + 1
            let toIndex = currentIndex + cachingAmount + 1
            fetchTodoList(from: fromIndex, to: toIndex)
        }
    }
}

// MARK: UseCases Binding
private extension HomeCalendarViewModel {
    func bind() {
        bindDate()
        bindCategoryUseCase()
        bindTodoUseCase()
        bindProfileUseCase()
        bindGroupUseCase()
    }
    
    func bindDate() {
        currentIndex
            .compactMap { $0 }
            .map { [weak self] in
                sharedCalendar.date(
                    byAdding: DateComponents(month: $0),
                    to: self?.firstMonth ?? Date()
                )
            }
            .bind(to: currentMonth)
            .disposed(by: bag)
        
        currentMonth
            .compactMap { $0 }
            .withUnretained(self)
            .map { vm, date in
                vm.useCases.dateFormatYYYYMMUseCase.execute(date: date)
            }
            .bind(to: dateTitle)
            .disposed(by: bag)
    }
    
    func bindGroupUseCase() {
        useCases.groupCreateUseCase
            .didCreateGroup
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.fetchAll()
            })
            .disposed(by: bag)
        
        useCases.withdrawGroupUseCase
            .didWithdrawGroup
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.fetchAll()
            })
            .disposed(by: bag)
        
        useCases.deleteGroupUseCase
            .didDeleteGroupWithId
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.fetchAll()
            })
            .disposed(by: bag)
    }
    
    func bindProfileUseCase() {
        useCases.updateProfileUseCase
            .didUpdateProfile
            .subscribe(onNext: { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                guard let imageUrl = profile.imageUrl else {
                    self.fetchedProfileImage.onNext(nil)
                    return
                }
                self.useCases.fetchImageUseCase.execute(key: imageUrl)
                    .subscribe(onSuccess: { data in
                        self.fetchedProfileImage.onNext(data)
                    })
                    .disposed(by: self.bag)
        })
        .disposed(by: bag)
    }
    
    func bindCategoryUseCase() {
        useCases.createCategoryUseCase
            .didCreateCategory
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                guard let id = category.id else { return }
                vm.memberCategories[id] = category
            })
            .disposed(by: bag)
        
        useCases.updateCategoryUseCase
            .didUpdateCategory
            .withUnretained(self)
            .subscribe(onNext: { vm, category in
                guard let id = category.id else { return }
                vm.memberCategories[id] = category
                vm.reDrawDailyViewModel()
            })
            .disposed(by: bag)
    }
    
    func bindTodoUseCase() {
        useCases.createTodoUseCase
            .didCreateTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                let indexSet = vm.createTodo(todo: todo)
                vm.drawDailyViewModels(with: .internalChange(indexSet))
            })
            .disposed(by: bag)
        
        useCases.updateTodoUseCase
            .didUpdateTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todoUpdate in
                let indexSet = vm.updateTodo(todoUpdate: todoUpdate)
                vm.drawDailyViewModels(with: .internalChange(indexSet))
            })
            .disposed(by: bag)
        
        useCases.deleteTodoUseCase
            .didDeleteTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                let indexSet = vm.deleteTodo(todo: todo)
                vm.drawDailyViewModels(with: .internalChange(indexSet))
            })
            .disposed(by: bag)
        
        useCases.todoCompleteUseCase
            .didCompleteTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                let indexSet = vm.completeTodo(todo: todo)
                vm.drawDailyViewModels(with: .internalChange(indexSet))
            })
            .disposed(by: bag)
    }
}

// MARK: Todo Actions
private extension HomeCalendarViewModel {
    func createTodo(todo: Todo) -> IndexSet {
        return searchSectionsTodoBelongs(todo) { [weak self] tmpDate in
            self?.todos[tmpDate, default: []].append(todo)
        }
    }
    
    func completeTodo(todo: Todo) -> IndexSet {
        return searchSectionsTodoBelongs(todo) { [weak self] tmpDate in
            guard let todoIndex = self?.todos[tmpDate]?.firstIndex(
                where: { $0.id == todo.id && $0.isGroupTodo == todo.isGroupTodo }
            ) else { return }
            self?.todos[tmpDate]?[todoIndex] = todo
        }
    }
    
    func updateTodo(todoUpdate: TodoUpdateComparator) -> IndexSet {
        let todoBeforeUpdate = todoUpdate.before
        let todoAfterUpdate = todoUpdate.after
        
        var sectionSet = IndexSet()
        let removeSet = deleteTodo(todo: todoBeforeUpdate)
        let insertSet = createTodo(todo: todoAfterUpdate)
        sectionSet = sectionSet.union(removeSet)
        sectionSet = sectionSet.union(insertSet)
        
        return sectionSet
    }
    
    func deleteTodo(todo: Todo) -> IndexSet {
        return searchSectionsTodoBelongs(todo) { [weak self] tmpDate in
            self?.todos[tmpDate]?.removeAll(
                where: { $0.id == todo.id && $0.isGroupTodo == todo.isGroupTodo }
            )
        }
    }
    
    func searchSectionsTodoBelongs(_ todo: Todo, with action: @escaping (Date) -> Void) -> IndexSet {
        var sectionSet = IndexSet()
        
        var tmpDate = todo.startDate
        
        while(tmpDate <= todo.endDate) {
            action(tmpDate)
            let sectionIndex = sharedCalendar.dateComponents([.month], from: firstMonth, to: tmpDate).month ?? 0
            let range = max(0, sectionIndex - 1) ... min(endOfLastIndex - endOfFirstIndex, sectionIndex + 1)
            sectionSet.insert(integersIn: range)
            tmpDate = sharedCalendar.date(byAdding: DateComponents(day: 1), to: tmpDate) ?? Date()
        }
        return sectionSet
    }
}

private extension HomeCalendarViewModel {
    func multipleDaysSelected(_ a: IndexPath, _ b: IndexPath) {
        let (startDate, endDate) = getOrderedDates(a, b)

        let groupList = Array(groups.values).sorted(by: { $0.groupId < $1.groupId })
        let groupName = try? filteredGroupId.value().flatMap { groups[$0] }

        actions.showCreatePeriodTodoPage?(
            MyTodoDetailViewModel.Args(
                groupList: groupList,
                type: .new(
                    date: DateRange(start: startDate, end: endDate),
                    group: groupName
                )
            )
        ) { [weak self] in
            self?.createPeriodTodoCompletionHandler?(IndexPath(item: 0, section: a.section))
        }
    }
    
    func getOrderedDates(_ a: IndexPath, _ b: IndexPath) -> (Date, Date) {
        var (startDate, endDate) = (mainDays[a.section][a.item].date, mainDays[b.section][b.item].date)
        if startDate > endDate {
            swap(&startDate, &endDate)
        }
        return (startDate, endDate)
    }
}

// MARK: Fetch Data
private extension HomeCalendarViewModel {
    func fetchTodoList(from startIndex: Int, to endIndex: Int) {
        guard let currentDate = try? self.currentMonth.value(),
              let currentIndex = try? self.currentIndex.value() else { return }
        
        let startMonth = sharedCalendar.date(byAdding: DateComponents(month: startIndex - currentIndex), to: currentDate) ?? Date()
        let endMonth = sharedCalendar.date(byAdding: DateComponents(month: endIndex - currentIndex), to: currentDate) ?? Date()
        
        let startDate = sharedCalendar.date(byAdding: DateComponents(day: -7), to: sharedCalendar.startOfDay(for: startMonth)) ?? Date()
        let endDate = sharedCalendar.date(byAdding: DateComponents(day: 7), to: sharedCalendar.startOfDay(for: endMonth)) ?? Date()
        
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.readTodoListUseCase
                    .execute(token: token, from: startDate, to: endDate)
            }
            .subscribe(onSuccess: { [weak self] todoDict in
                guard let self else { return }
                self.todos.merge(todoDict) { (_, new) in new }
                self.drawDailyViewModels(with: .apiFetched(IndexSet((startIndex...endIndex))))
                if self.nowRefreshing {
                    self.nowRefreshing = false
                    self.refreshFinished.onNext(())
                }
            })
            .disposed(by: bag)
    }
    
    func fetchAll() {
        Observable.zip(
            groupsFetcher().asObservable(),
            categoriesFetcher().asObservable(),
            groupCategoriesFetcher().asObservable()
        )
        .withUnretained(self)
        .subscribe(onNext: { vm, _ in
            vm.initTodoList()
        })
        .disposed(by: bag)
    }
    
    func groupsFetcher() -> Single<[GroupName]> {
        useCases
            .executeWithTokenUseCase
            .execute { [weak self] token in
                self?.useCases
                    .fetchMyGroupNameListUseCase
                    .execute(token: token)
            }
            .do(onSuccess: { [weak self] groups in
                self?.groups.removeAll()
                groups.forEach {
                    self?.groups[$0.groupId] = $0
                }
                self?.groupListFetched.onNext(groups.sorted(by: { $0.groupId < $1.groupId }))
            })
    }
    
    func categoriesFetcher() -> Single<[Category]> {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                self?.useCases
                    .readCategoryListUseCase
                    .execute(token: token)
            }
            .do(onSuccess: { [weak self] categories in
                self?.memberCategories.removeAll()
                categories.forEach {
                    guard let id = $0.id else { return }
                    self?.memberCategories[id] = $0
                }
            })
    }
    
    func groupCategoriesFetcher() -> Single<[Category]> {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                self?.useCases.fetchGroupCategoryListUseCase.execute(token: token)
            }
            .do(onSuccess: { [weak self] categories in
                self?.groupCategories.removeAll()
                categories.forEach {
                    guard let id = $0.id else { return }
                    self?.groupCategories[id] = $0
                }
            })
    }
    
    func fetchProfile() {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.readProfileUseCase
                    .execute(token: token)
            }
            .subscribe(onSuccess: { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                self.showAlert.onNext(Message(text: "\(profile.nickName)님 반갑습니다!", state: .normal))

                guard let imageUrl = profile.imageUrl else { return }
                self.useCases.fetchImageUseCase.execute(key: imageUrl)
                    .subscribe(onSuccess: { data in
                        self.fetchedProfileImage.onNext(data)
                    })
                    .disposed(by: self.bag)
            })
            .disposed(by: bag)
    }
}

// MARK: - 섹션별로 dailyViewModel 그리기
private extension HomeCalendarViewModel {
    func drawDailyViewModels(with type: SectionChange) {
        switch type {
        case .apiFetched(let sectionSet), .internalChange(let sectionSet):
            sectionSet.forEach { section in
                todoStackingBuffer = [[Bool]](repeating: [Bool](repeating: false, count: 30), count: 42)
                (0..<mainDays[section].count).forEach { item in
                    guard item%7 == 0 else { return }
                    stackDailyViewModelsOfWeek(at: IndexPath(item: item, section: section))
                }
            }
            reloadSectionSet.onNext(type)
        }
    }
    
    func reDrawDailyViewModel() {
        let indexSet = IndexSet(prevBufferRequestedIndex-cachingAmount...followingBufferRequestedIndex+cachingAmount)
        drawDailyViewModels(with: .internalChange(indexSet))
    }
}

// MARK: 주 단위로 뷰모델 셋팅
private extension HomeCalendarViewModel {
    func stackDailyViewModelsOfWeek(at indexPath: IndexPath) {
        guard indexPath.item % 7 == 0 else { return }
        
        Array(mainDays[indexPath.section].enumerated())[indexPath.item..<indexPath.item + 7].forEach { (item, day) in
            guard var todoList = todos[day.date] else {
                if HolidayPool.shared.holidays[day.date] != nil {
                    let holiday = determineHoliday(indexPath: IndexPath(item: item, section: indexPath.section), totalTodoCount: 0)
                    dailyViewModels[day.date] = DailyViewModel(periodTodo: [], singleTodo: [], holiday: holiday)
                }
                return
            }
            
            if let filterGroupId = try? filteredGroupId.value() {
                todoList = todoList.filter( { $0.groupId == filterGroupId })
            }
            
            let singleTodoList = prepareSingleTodosInDay(at: IndexPath(item: item, section: indexPath.section), todos: todoList)
            let periodTodoList = preparePeriodTodosInDay(at: IndexPath(item: item, section: indexPath.section), todos: todoList)
            
            dailyViewModels[day.date] = generateDailyViewModel(
                at: IndexPath(item: item, section: indexPath.section),
                singleTodos: singleTodoList,
                periodTodos: periodTodoList
            )
            
            
        }
    }
}

// MARK: - 주 단위로 셀의 높이를 맞추기 위한 메서드
extension HomeCalendarViewModel {
    func getDayHeight(at indexPath: IndexPath) -> Int {
        let date = mainDays[indexPath.section][indexPath.item].date
        guard let viewModel = dailyViewModels[date] else { return 0 }
        
        return viewModel.holiday != nil
        ? viewModel.holiday!.0 + 1 : viewModel.singleTodo.last != nil
        ? viewModel.singleTodo.last!.0 + 1 : viewModel.periodTodo.last != nil
        ? viewModel.periodTodo.last!.0 + 1 : 0
    }
    
    func largestDailyViewModelOfWeek(at indexPath: IndexPath) -> (Int, DailyViewModel?) {
        let weekRange = (indexPath.item - indexPath.item%7..<indexPath.item - indexPath.item%7 + 7)
        
        let result = weekRange.map { (index: Int) -> (Int, DailyViewModel?) in
            let date = mainDays[indexPath.section][index].date
            return (getDayHeight(at: IndexPath(item: index, section: indexPath.section)), dailyViewModels[date])
        }.max { $0.0 < $1.0 }

        return result ?? (0, nil)
    }
}

// MARK: prepare DailyViewModel
private extension HomeCalendarViewModel {
    func generateDailyViewModel(at indexPath: IndexPath, singleTodos: [Todo], periodTodos: [Todo]) -> DailyViewModel {
        let filteredPeriodTodos: [(Int, TodoSummaryViewModel)] = mapPeriodTodosToViewModels(indexPath: indexPath, periodTodos: periodTodos)
        let singleTodoInitialIndex = calculateSingleTodoInitialIndex(indexPath: indexPath, singleTodos: singleTodos)
        let filteredSingleTodos = mapSingleTodosToViewModels(indexOffset: singleTodoInitialIndex, singleTodos: singleTodos)
        let holiday = determineHoliday(indexPath: indexPath, totalTodoCount: singleTodoInitialIndex + filteredSingleTodos.count)
        
        return DailyViewModel(periodTodo: filteredPeriodTodos, singleTodo: filteredSingleTodos, holiday: holiday)
    }
    
    private func mapPeriodTodosToViewModels(indexPath: IndexPath, periodTodos: [Todo]) -> [(Int, TodoSummaryViewModel)] {
        var filteredPeriodTodos: [(Int, TodoSummaryViewModel)] = []
        
        for todo in periodTodos {
            for i in 0..<todoStackingBuffer[indexPath.item].count {
                if todoStackingBuffer[indexPath.item][i] == false,
                    let period = sharedCalendar.dateComponents([.day], from: todo.startDate, to: todo.endDate).day {
                    for j in 0...period {
                        todoStackingBuffer[indexPath.item+j][i] = true
                    }
                    let viewModelColor = todo.isGroupTodo ?
                    (groupCategories[todo.categoryId]?.color ?? .none) : (memberCategories[todo.categoryId]?.color ?? .none)
                    let viewModel = todo.toViewModel(color: viewModelColor)
                    filteredPeriodTodos.append((i, viewModel))
                    break
                }
            }
        }
        return filteredPeriodTodos
    }
    
    private func calculateSingleTodoInitialIndex(indexPath: IndexPath, singleTodos: [Todo]) -> Int {
        let lastFilledIndex = todoStackingBuffer[indexPath.item].lastIndex { $0 == true } ?? -1
        return lastFilledIndex + 1
    }
    
    private func mapSingleTodosToViewModels(indexOffset: Int, singleTodos: [Todo]) -> [(Int, TodoSummaryViewModel)] {
        return singleTodos.enumerated().map { (index, todo) in
            let viewModelColor = todo.isGroupTodo ? (groupCategories[todo.categoryId]?.color ?? .none) : (memberCategories[todo.categoryId]?.color ?? .none)
            let viewModel = todo.toViewModel(color: viewModelColor)
            return (index + indexOffset, viewModel)
        }
    }
    
    private func determineHoliday(indexPath: IndexPath, totalTodoCount: Int) -> (Int, String)? {
        if let holidayTitle = HolidayPool.shared.holidays[mainDays[indexPath.section][indexPath.item].date] {
            let holidayIndex = totalTodoCount
            return (holidayIndex, holidayTitle)
        }
        return nil
    }
}

// MARK: - filter Todos
private extension HomeCalendarViewModel {
    
    func prepareSingleTodosInDay(at indexPath: IndexPath, todos: [Todo]) -> [Todo] {
        return todos.filter { $0.startDate == $0.endDate }
    }
    
    func preparePeriodTodosInDay(at indexPath: IndexPath, todos: [Todo]) -> [Todo] {
        var periodList = todos.filter { $0.startDate != $0.endDate }
        
        let date = mainDays[indexPath.section][indexPath.item].date
        let endDateOfWeek = sharedCalendar.endDateOfTheWeek(from: date)
        
        if indexPath.item % 7 != 0 {
            periodList = periodList
                .filter { $0.startDate == date }
                .sorted { $0.endDate < $1.endDate }
        } else {
            periodList = periodList
                .sorted{ ($0.startDate == $1.startDate) ? $0.endDate < $1.endDate : $0.startDate < $1.startDate }
                .map { todo in
                    var tmpTodo = todo
                    tmpTodo.startDate = date
                    return tmpTodo
                }
        }

        return periodList.map { todo in
            var tmpTodo = todo
            tmpTodo.endDate = min(endDateOfWeek, todo.endDate)
            return tmpTodo
        }
    }
}

// MARK: Title Year-Month generator
private extension HomeCalendarViewModel {
    func indexOfMonth(_ date: Date) -> Int {
        return sharedCalendar.dateComponents(
            [.month],
            from: sharedCalendar.startDayOfMonth(date: firstMonth), to: date
        ).month ?? 0
    }
}
