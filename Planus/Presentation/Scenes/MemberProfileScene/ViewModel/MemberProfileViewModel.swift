//
//  MemberProfileViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/06.
//

import Foundation
import RxSwift

extension MemberProfileViewModel {
    enum CalendarMovable {
        case scroll(Int)
        case jump(Int)
        case initialized(Int)
    }
}

final class MemberProfileViewModel: ViewModelable {
    
    struct UseCases {
        let createMonthlyCalendarUseCase: CreateMonthlyCalendarUseCase
        let dateFormatYYYYMMUseCase: DateFormatYYYYMMUseCase
        let executeWithTokenUseCase: ExecuteWithTokenUseCase
        let fetchMemberCalendarUseCase: FetchGroupMemberCalendarUseCase
        let fetchImageUseCase: FetchImageUseCase
    }
    
    struct Actions {
        let showSocialDailyCalendar: ((MemberDailyCalendarViewModel.Args) -> Void)?
        let pop: (() -> Void)?
        let finishScene: (() -> Void)?
    }
    
    struct Args {
        let group: GroupName
        let member: MyGroupMemberProfile
    }
    
    struct Injectable {
        let actions: Actions
        let args: Args
    }
    
    var bag = DisposeBag()
    let useCases: UseCases
    let actions: Actions
    
    let calendar = Calendar.current
    
    let group: GroupName
    let member: MyGroupMemberProfile
    
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
    
    // MARK: Models
    var mainDays = [[Day]]()
    var todos = [Date: [TodoSummaryViewModel]]()
    
    var dailyViewModels = [Date: DailyViewModel]()
    
    // MARK: UI Generater, Buffer
    var todoStackingBuffer = [[Bool]](repeating: [Bool](repeating: false, count: 30), count: 42)
    var cachedCellHeightForTodoCount = [Int: Double]()
    
    private var currentIndex = BehaviorSubject<Int>(value: 0)
    
    private let reloadSectionSet = PublishSubject<IndexSet>()
    private let needMoveToIndex = BehaviorSubject<CalendarMovable?>(value: nil)
    private let profileImage = BehaviorSubject<Data?>(value: nil)
    private let showMonthPicker = PublishSubject<(first: Date, current: Date, last: Date)>()
    private let showAlert = PublishSubject<Message>()
    
    struct Input {
        var viewDidLoaded: Observable<Void>
        var movedToIndex: Observable<CalendarMovable>
        var itemSelectedAt: Observable<IndexPath>
        var titleBtnTapped: Observable<Void>
        var monthSelected: Observable<Date>
        var backBtnTapped: Observable<Void> 
    }
    
    struct Output {
        var dateTitleUpdated: Observable<String?>
        var needMoveTo: Observable<CalendarMovable?>
        var showMonthPicker: Observable<(first: Date, current: Date, last: Date)>
        var reloadSectionSet: Observable<IndexSet>
        var showAlert: Observable<Message>
        var memberName: String?
        var memberDesc: String?
        var memberImage: Observable<Data?>
    }
    
    init(
        useCases: UseCases,
        injectable: Injectable
    ) {
        self.useCases = useCases
        self.actions = injectable.actions
        
        self.group = injectable.args.group
        self.member = injectable.args.member
        
        self.today = sharedCalendar.startOfDay(date: Date())
        self.firstMonth = sharedCalendar.date(
            byAdding: .month,
            value: self.endOfFirstIndex,
            to: sharedCalendar.startDayOfMonth(date: self.today)
        ) ?? Date()
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
    
    func transform(input: Input) -> Output {
        input.viewDidLoaded
            .withUnretained(self)
            .subscribe { vm, _ in
                vm.bindDate()
                vm.initCalendar()
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
                vm.actions.showSocialDailyCalendar?(
                    MemberDailyCalendarViewModel.Args(
                        group: vm.group,
                        memberId: vm.member.memberId,
                        date: vm.mainDays[indexPath.section][indexPath.item].date
                    )
                )
            }
            .disposed(by: bag)
        
        input
            .titleBtnTapped
            .withUnretained(self)
            .subscribe { vm, _ in
                guard let currentMonth = try? vm.currentMonth.value() else { return }
                let first = vm.firstMonth
                let last = sharedCalendar.date(
                    byAdding: .month,
                    value: vm.endOfLastIndex - vm.endOfFirstIndex,
                    to: first
                )!
                vm.showMonthPicker.onNext((first, currentMonth, last))
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
            .backBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.pop?()
            })
            .disposed(by: bag)
        
        if let url = member.profileImageUrl {
            fetchImage(key: url)
                .subscribe(onSuccess: { [weak self] data in
                    self?.profileImage.onNext(data)
                })
                .disposed(by: bag)
        }
        
        return Output(
            dateTitleUpdated: dateTitle.asObservable(),
            needMoveTo: needMoveToIndex.asObservable(),
            showMonthPicker: showMonthPicker.asObservable(),
            reloadSectionSet: reloadSectionSet.asObservable(),
            showAlert: showAlert.asObservable(),
            memberName: member.nickname,
            memberDesc: member.description,
            memberImage: profileImage.asObservable()
        )
    }
}

private extension MemberProfileViewModel {
    func scrolledTo(index: Int) {
        currentIndex.onNext(index)
        checkCacheLoadNeed(currentIndex: index)
    }
    
    func jumpedTo(index: Int) {
        currentIndex.onNext(index)
        initTodoList(index: index)
    }
}

// MARK: - calendar UI
private extension MemberProfileViewModel {
    func initCalendar() {
        mainDays = (0...endOfLastIndex - endOfFirstIndex).map { diff -> [Day] in
            let calendarDate = sharedCalendar.date(byAdding: DateComponents(month: diff), to: firstMonth) ?? Date()
            return useCases.createMonthlyCalendarUseCase.execute(date: calendarDate)
        }
        
        let center = -endOfFirstIndex
        needMoveToIndex.onNext(.initialized(center))
    }
    
    func initTodoList(index: Int) {
        prevBufferRequestedIndex = index
        followingBufferRequestedIndex = index
        
        let fromIndex = (index - cachingAmount >= 0) ? index - cachingAmount : 0
        let toIndex = index + cachingAmount + 1 < mainDays.count ? index + cachingAmount + 1 : mainDays.count-1
        
        todos.removeAll()
        dailyViewModels.removeAll()

        fetchTodoList(from: fromIndex, to: toIndex)
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

// MARK: - api fetcher
extension MemberProfileViewModel {
    
    func fetchTodoList(from firstIndex: Int, to lastIndex: Int) {
        guard let currentDate = try? self.currentMonth.value(),
              let currentIndex = try? self.currentIndex.value() else { return }
        
        let firstMonth = calendar.date(byAdding: DateComponents(month: firstIndex - currentIndex), to: currentDate) ?? Date()
        let lastMonth = calendar.date(byAdding: DateComponents(month: lastIndex - currentIndex), to: currentDate) ?? Date()
        
        let firstMonthStart = calendar.date(byAdding: DateComponents(day: -7), to: calendar.startOfDay(for: firstMonth)) ?? Date()
        let lastMonthStart = calendar.date(byAdding: DateComponents(day: 7), to: calendar.startOfDay(for: lastMonth)) ?? Date()

        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token -> Single<[Date: [TodoSummaryViewModel]]>? in
                guard let self else { return nil }
                return self.useCases.fetchMemberCalendarUseCase
                    .execute(
                        token: token,
                        groupId: self.group.groupId,
                        memberId: self.member.memberId,
                        from: firstMonthStart,
                        to: lastMonthStart
                    )
            }
            .subscribe(onSuccess: { [weak self] todoDict in
                guard let self else { return }
                self.todos.merge(todoDict) { (_, new) in new }
                
                self.drawDailyViewModels(indexSet: IndexSet(firstIndex...lastIndex))
            })
            .disposed(by: bag)
    }
    
    
    func fetchImage(key: String) -> Single<Data> {
        useCases
            .fetchImageUseCase
            .execute(key: key)
    }
}

// MARK: - DailyViewModel 그리기
extension MemberProfileViewModel {
    func drawDailyViewModels(indexSet: IndexSet) {
        indexSet.forEach { section in
            todoStackingBuffer = [[Bool]](repeating: [Bool](repeating: false, count: 30), count: 42)
            (0..<mainDays[section].count).forEach { item in
                if item%7 == 0 {
                    stackDailyViewModelsOfWeek(at: IndexPath(item: item, section: section))
                }
            }
        }
        self.reloadSectionSet.onNext(indexSet)
    }
}

// MARK: VC쪽 UI용 투두 ViewModel 준비를 위해 요청
extension MemberProfileViewModel {
    func stackDailyViewModelsOfWeek(at indexPath: IndexPath) {
        guard indexPath.item % 7 == 0 else { return }

        Array(mainDays[indexPath.section].enumerated())[indexPath.item..<indexPath.item + 7].forEach { (item, day) in
            guard let todoList = todos[day.date] else {
                if HolidayPool.shared.holidays[day.date] != nil {
                    let holiday = determineHoliday(indexPath: IndexPath(item: item, section: indexPath.section), totalTodoCount: 0)
                    dailyViewModels[day.date] = DailyViewModel(periodTodo: [], singleTodo: [], holiday: holiday)
                }
                return
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
private extension MemberProfileViewModel {
    func generateDailyViewModel(at indexPath: IndexPath, singleTodos: [TodoSummaryViewModel], periodTodos: [TodoSummaryViewModel]) -> DailyViewModel {
        let filteredPeriodTodos: [(Int, TodoSummaryViewModel)] = mapPeriodTodosToViewModels(indexPath: indexPath, periodTodos: periodTodos)
        let singleTodoInitialIndex = calculateSingleTodoInitialIndex(indexPath: indexPath, singleTodos: singleTodos)
        let filteredSingleTodos = mapSingleTodosToViewModels(indexOffset: singleTodoInitialIndex, singleTodos: singleTodos)
        let holiday = determineHoliday(indexPath: indexPath, totalTodoCount: singleTodoInitialIndex + filteredSingleTodos.count)
        
        return DailyViewModel(periodTodo: filteredPeriodTodos, singleTodo: filteredSingleTodos, holiday: holiday)
    }

    private func mapPeriodTodosToViewModels(indexPath: IndexPath, periodTodos: [TodoSummaryViewModel]) -> [(Int, TodoSummaryViewModel)] {
        var filteredPeriodTodos: [(Int, TodoSummaryViewModel)] = []
        
        for todo in periodTodos {
            for i in 0..<todoStackingBuffer[indexPath.item].count {
                if todoStackingBuffer[indexPath.item][i] == false,
                    let period = sharedCalendar.dateComponents([.day], from: todo.startDate, to: todo.endDate).day {
                    for j in 0...period {
                        todoStackingBuffer[indexPath.item+j][i] = true
                    }
                    filteredPeriodTodos.append((i, todo))
                    break
                }
            }
        }
        return filteredPeriodTodos
    }

    private func calculateSingleTodoInitialIndex(indexPath: IndexPath, singleTodos: [TodoSummaryViewModel]) -> Int {
        let lastFilledIndex = todoStackingBuffer[indexPath.item].lastIndex { $0 == true } ?? -1
        return lastFilledIndex + 1
    }

    private func mapSingleTodosToViewModels(indexOffset: Int, singleTodos: [TodoSummaryViewModel]) -> [(Int, TodoSummaryViewModel)] {
        return singleTodos.enumerated().map { (index, todo) in
            return (index + indexOffset, todo)
        }
    }

    private func determineHoliday(indexPath: IndexPath, totalTodoCount: Int) -> (Int, String)? {
        if let holidayTitle = HolidayPool.shared.holidays[mainDays[indexPath.section][indexPath.item].date] {
            let holidayIndex = totalTodoCount
            return (holidayIndex, holidayTitle)
        }
        return nil
    }
    
    func prepareSingleTodosInDay(at indexPath: IndexPath, todos: [TodoSummaryViewModel]) -> [TodoSummaryViewModel] {
        return todos.filter { $0.startDate == $0.endDate }
    }
    
    func preparePeriodTodosInDay(at indexPath: IndexPath, todos: [TodoSummaryViewModel]) -> [TodoSummaryViewModel] {
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
private extension MemberProfileViewModel {
    func indexOfMonth(_ date: Date) -> Int {
        return sharedCalendar.dateComponents(
            [.month],
            from: sharedCalendar.startDayOfMonth(date: firstMonth), to: date
        ).month ?? 0
    }
}
