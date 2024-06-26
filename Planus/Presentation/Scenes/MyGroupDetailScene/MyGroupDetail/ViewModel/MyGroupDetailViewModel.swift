//
//  MyGroupDetailViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/22.
//

import Foundation
import RxSwift

enum MyGroupDetailNavigatorType: Int, CaseIterable {
    case dot = 0
    case notice
    case calendar
}

enum MyGroupSecionType {
    case info
    case notice
    case member
    case calendar
    case chat
}

final class MyGroupDetailViewModel: ViewModelable {
    
    struct UseCases {
        let fetchMyGroupDetailUseCase: FetchMyGroupDetailUseCase
        let updateNoticeUseCase: UpdateNoticeUseCase
        let updateInfoUseCase: UpdateGroupInfoUseCase
        let withdrawGroupUseCase: WithdrawGroupUseCase
        
        let fetchMyGroupMemberListUseCase: FetchMyGroupMemberListUseCase
        let fetchImageUseCase: FetchImageUseCase
        let memberKickOutUseCase: MemberKickOutUseCase
        let setOnlineUseCase: SetOnlineUseCase
        
        let executeWithTokenUseCase: ExecuteWithTokenUseCase
        
        let createMonthlyCalendarUseCase: CreateMonthlyCalendarUseCase
        let fetchMyGroupCalendarUseCase: FetchGroupMonthlyCalendarUseCase
        
        let createGroupTodoUseCase: CreateGroupTodoUseCase
        let updateGroupTodoUseCase: UpdateGroupTodoUseCase
        let deleteGroupTodoUseCase: DeleteGroupTodoUseCase
        let updateGroupCategoryUseCase: UpdateGroupCategoryUseCase
        
        let generateGroupLinkUseCase: GenerateGroupLinkUseCase
    }
    
    struct Actions {
        let showDailyCalendar: ((GroupDailyCalendarViewModel.Args) -> Void)?
        let showMemberProfile: ((MemberProfileViewModel.Args) -> Void)?
        let editInfo: ((MyGroupInfoEditViewModel.Args) -> Void)?
        let editMember: ((MyGroupMemberEditViewModel.Args) -> Void)?
        let editNotice: ((MyGroupNoticeEditViewModel.Args) -> Void)?
        let pop: (() -> Void)?
        let finishScene: (() -> Void)?
    }
    
    struct Args {
        let groupId: Int
    }
    
    struct Injectable {
        let actions: Actions
        let args: Args
    }
    
    
    let bag = DisposeBag()
    
    let useCases: UseCases
    let actions: Actions
    
    struct Input {
        var viewDidLoad: Observable<Void>
        var didTappedModeBtnAt: Observable<Int>
        var didChangedMonth: Observable<Date>
        var didSelectedDayAt: Observable<Int>
        var didSelectedMemberAt: Observable<Int>
        var didTappedOnlineButton: Observable<Void>
        var didTappedShareBtn: Observable<Void>
        var didTappedInfoEditBtn: Observable<Void>
        var didTappedMemberEditBtn: Observable<Void>
        var didTappedNoticeEditBtn: Observable<Void>
        var backBtnTapped: Observable<Void>
    }
    
    struct Output {
        var showMessage: Observable<Message>
        var didInitialFetch: Observable<Void>
        var didFetchInfo: Observable<Void?>
        var didFetchNotice: Observable<Void?>
        var didFetchMember: Observable<Void?>
        var didFetchCalendar: Observable<Void?>
        var nowLoadingWithBefore: Observable<MyGroupDetailPageType?>
        var memberKickedOutAt: Observable<Int>
        var needReloadMemberAt: Observable<Int>
        var onlineStateChanged: Observable<Bool?>
        var modeChanged: Observable<Void>
        var showShareMenu: Observable<String?>
        var nowInitLoading: Observable<Void?>
    }
    
    var nowLoadingWithBefore = BehaviorSubject<MyGroupDetailPageType?>(value: nil)
    var nowInitLoading = BehaviorSubject<Void?>(value: nil)
    
    var didFetchInfo = BehaviorSubject<Void?>(value: nil)
    var didFetchNotice = BehaviorSubject<Void?>(value: nil)
    var didFetchMember = BehaviorSubject<Void?>(value: nil)
    var didFetchCalendar = BehaviorSubject<Void?>(value: nil)
    var showShareMenu = PublishSubject<String?>()
    
    let groupId: Int
    
    var groupTitle: String?
    var groupImageUrl: String?
    var tag: [String]?
    var memberCount: Int?
    var limitCount: Int?
    var leaderName: String?
    var isLeader: Bool?
    
    var onlineCount: Int?
    
    var isOnline = BehaviorSubject<Bool?>(value: nil)
    
    // MARK: mode 0, notice section
    var notice: String?
    var memberList: [MyGroupMemberProfile]?
    var memberKickedOutAt = PublishSubject<Int>()
    var needReloadMemberAt = PublishSubject<Int>()
    
    // MARK: model, calendar section
    let today: Date
    var currentDate: Date?
    var dateTitle: String?
    
    var mainDays = [Day]()
    var todos = [Date: [TodoSummaryViewModel]]()
    
    // MARK: UI Generating Buffer
    var todoStackingBuffer = [[Bool]](repeating: [Bool](repeating: false, count: 30), count: 42)
    var dailyViewModels = [Date: DailyViewModel]()
    var cachedCellHeightForTodoCount = [Int: Double]()
    
    var showDaily = PublishSubject<Date>()
    
    var mode: MyGroupDetailPageType?
    
    let showMessage = PublishSubject<Message>()
    let modeChanged = PublishSubject<Void>()
    
    lazy var membersFetcher: (Int) -> Single<[MyGroupMemberProfile]>? = { [weak self] groupId in
        guard let self else { return nil }
        return self.useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchMyGroupMemberListUseCase
                    .execute(token: token, groupId: groupId)
            }
    }
    
    lazy var groupDetailFetcher: (Int) -> Single<MyGroupDetail>? = { [weak self] groupId in
        guard let self else { return nil }
        return self.useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchMyGroupDetailUseCase
                    .execute(token: token, groupId: groupId)
            }
    }
    
    
    init(
        useCases: UseCases,
        injectable: Injectable
    ) {
        self.useCases = useCases
        self.actions = injectable.actions
        
        self.groupId = injectable.args.groupId
        self.today = sharedCalendar.startOfDay(date: Date())
    }
    
    func transform(input: Input) -> Output {
        
        bindUseCase()
        
        input
            .viewDidLoad
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.mode = .notice
                vm.nowInitLoading.onNext(())
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    vm.initFetchDetails(groupId: vm.groupId)
                })
            })
            .disposed(by: bag)
        
        input
            .didTappedModeBtnAt
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                vm.changeMode(to: index)
            })
            .disposed(by: bag)
        
        input
            .didChangedMonth
            .withUnretained(self)
            .subscribe(onNext: { vm, date in
                vm.mode = .calendar
                vm.createCalendar(date: date)
            })
            .disposed(by: bag)
        
        input
            .didSelectedMemberAt
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                guard let groupTitle = vm.groupTitle,
                      let member = vm.memberList?[index] else { return }
                
                vm.actions.showMemberProfile?(
                    MemberProfileViewModel.Args(
                        group: GroupName(groupId: vm.groupId, groupName: groupTitle),
                        member: member
                    )
                )
            })
            .disposed(by: bag)
        
        input
            .didSelectedDayAt
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                vm.actions.showDailyCalendar?(
                    GroupDailyCalendarViewModel.Args(
                        group: GroupName(groupId: vm.groupId, groupName: vm.groupTitle ?? String()),
                        isLeader: vm.isLeader ?? Bool(),
                        date: vm.mainDays[index].date
                    )
                )
            })
            .disposed(by: bag)
        
        input
            .didTappedOnlineButton
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.flipOnlineState()
            })
            .disposed(by: bag)
        
        input
            .didTappedShareBtn
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                let urlString = vm.generateShareLink()
                vm.showShareMenu.onNext(urlString)
            })
            .disposed(by: bag)
        
        input
            .didTappedInfoEditBtn
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.editInfo?(
                    MyGroupInfoEditViewModel.Args(
                        id: vm.groupId,
                        title: vm.groupTitle ?? String(),
                        imageUrl: vm.groupImageUrl ?? String(),
                        tagList: vm.tag ?? [String](),
                        maxMember: vm.limitCount ?? Int()
                    )
                )
            })
            .disposed(by: bag)
        
        input
            .didTappedNoticeEditBtn
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.editNotice?(
                    MyGroupNoticeEditViewModel.Args(
                        groupId: vm.groupId,
                        notice: vm.notice ?? String()
                    )
                )
            })
            .disposed(by: bag)
        
        input
            .didTappedMemberEditBtn
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.editMember?(MyGroupMemberEditViewModel.Args(groupId: vm.groupId))
            })
            .disposed(by: bag)
        
        input
            .backBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions.pop?()
            })
            .disposed(by: bag)
        
        let initFetched = Observable.zip(
            didFetchInfo.compactMap { $0 },
            didFetchNotice.compactMap { $0 },
            didFetchMember.compactMap { $0 }
        ).map { _ in () }
        
        return Output(
            showMessage: showMessage.asObservable(),
            didInitialFetch: initFetched,
            didFetchInfo: didFetchInfo.asObservable(),
            didFetchNotice: didFetchNotice.asObservable(),
            didFetchMember: didFetchMember.asObservable(),
            didFetchCalendar: didFetchCalendar.asObservable(),
            nowLoadingWithBefore: nowLoadingWithBefore.asObservable(),
            memberKickedOutAt: memberKickedOutAt.asObservable(),
            needReloadMemberAt: needReloadMemberAt.asObservable(),
            onlineStateChanged: isOnline.asObservable(),
            modeChanged: modeChanged.asObservable(),
            showShareMenu: showShareMenu.asObservable(),
            nowInitLoading: nowInitLoading.asObservable()
        )
    }
}

// MARK: - Mode Actions
private extension MyGroupDetailViewModel {
    func changeMode(to index: Int) {
        let mode = MyGroupDetailPageType(rawValue: index)
        self.mode = mode
        self.modeChanged.onNext(())
        switch mode {
        case .notice:
            if memberList?.isEmpty ?? true {
                nowLoadingWithBefore.onNext(mode)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                    guard let self else { return }
                    fetchMemberList(groupId: groupId)
                })
            } else {
                self.mode = .notice
                didFetchNotice.onNext(())
            }
        case .calendar:
            if mainDays.isEmpty {
                nowLoadingWithBefore.onNext(mode)
                let components = Calendar.current.dateComponents(
                    [.year, .month],
                    from: Date()
                )
                
                let currentDate = Calendar.current.date(from: components) ?? Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                    self?.createCalendar(date: currentDate)
                })
                
            } else {
                didFetchCalendar.onNext(())
            }
        default: return
        }
    }
}

private extension MyGroupDetailViewModel {
    func generateShareLink() -> String? {
        return useCases.generateGroupLinkUseCase.execute(groupId: groupId)
    }
}

// MARK: - bind UseCases
private extension MyGroupDetailViewModel {
    func bindUseCase() {
        useCases
            .setOnlineUseCase
            .didChangeOnlineState
            .withUnretained(self)
            .subscribe(onNext: { vm, arg in
                let (groupId, memberId) = arg
                guard groupId == vm.groupId else { return }
                vm.changeOnlineState(memberId: memberId)
            })
            .disposed(by: bag)
        
        useCases
            .updateNoticeUseCase
            .didUpdateNotice
            .withUnretained(self)
            .subscribe(onNext: { vm, groupNotice in
                guard vm.groupId == groupNotice.groupId else { return }
                vm.notice = groupNotice.notice
                if vm.mode == .notice {
                    vm.didFetchNotice.onNext(())
                    vm.showMessage.onNext(Message(text: "공지사항을 업데이트 하였습니다.", state: .normal))
                }
            })
            .disposed(by: bag)
        
        useCases
            .updateInfoUseCase
            .didUpdateInfoWithId
            .withUnretained(self)
            .subscribe(onNext: { vm, id in
                guard id == vm.groupId else { return }
                vm.fetchGroupDetail(groupId: id)
            })
            .disposed(by: bag)
        
        useCases
            .createGroupTodoUseCase
            .didCreateGroupTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                guard vm.groupId == todo.groupId else { return }
                let startDate = vm.mainDays.first?.date ?? Date()
                let endDate = vm.mainDays.last?.date ?? Date()
                vm.fetchTodo(from: startDate, to: endDate)
            })
            .disposed(by: bag)
        
        useCases
            .updateGroupTodoUseCase
            .didUpdateGroupTodo
            .withUnretained(self)
            .subscribe(onNext: { vm, todo in
                guard vm.groupId == todo.groupId else { return }
                let startDate = vm.mainDays.first?.date ?? Date()
                let endDate = vm.mainDays.last?.date ?? Date()
                vm.fetchTodo(from: startDate, to: endDate)
            })
            .disposed(by: bag)
        
        useCases
            .deleteGroupTodoUseCase
            .didDeleteGroupTodoWithIds
            .withUnretained(self)
            .subscribe(onNext: { vm, ids in
                guard vm.groupId == ids.groupId else { return }
                let startDate = vm.mainDays.first?.date ?? Date()
                let endDate = vm.mainDays.last?.date ?? Date()
                vm.fetchTodo(from: startDate, to: endDate)
            })
            .disposed(by: bag)
        
        useCases
            .updateGroupCategoryUseCase
            .didUpdateCategoryWithGroupId
            .withUnretained(self)
            .subscribe(onNext: { vm, categoryWithGroupId in
                guard vm.groupId == categoryWithGroupId.groupId else { return }
                let startDate = vm.mainDays.first?.date ?? Date()
                let endDate = vm.mainDays.last?.date ?? Date()
                vm.fetchTodo(from: startDate, to: endDate)
            })
            .disposed(by: bag)
        
        useCases
            .memberKickOutUseCase
            .didKickOutMemberAt
            .withUnretained(self)
            .subscribe(onNext: { vm, args in
                let (groupId, memberId) = args
                guard groupId == vm.groupId,
                      let index = vm.memberList?.firstIndex(where: { $0.memberId == memberId }) else { return }
                vm.memberList?.remove(at: index)
                if vm.mode == .notice {
                    vm.memberKickedOutAt.onNext(index)
                }
            })
            .disposed(by: bag)
        
    }
}

private extension MyGroupDetailViewModel {
    func changeOnlineState(memberId: Int) {
        guard let exValue = try? isOnline.value(),
              let onlineCount else { return }
        let newValue = !exValue
        
        self.onlineCount = newValue ? (onlineCount + 1) : (onlineCount - 1)
        isOnline.onNext(newValue)
        
        showMessage.onNext(Message(text: "\(groupTitle ?? "") 그룹을 \(newValue ? "온" : "오프")라인으로 전환하였습니다.", state: .normal))
        guard let index = memberList?.firstIndex(where: { $0.memberId == memberId }),
              var member = memberList?[index] else { return }
        
        member.isOnline = !member.isOnline
        memberList?[index] = member
        
        if mode == .notice {
            needReloadMemberAt.onNext(index)
        }
        
    }
}

private extension MyGroupDetailViewModel {
    func setGroupDetail(detail: MyGroupDetail) {
        self.isLeader = detail.isLeader
        self.groupTitle = detail.groupName
        self.groupImageUrl = detail.groupImageUrl
        self.tag = detail.groupTags.map { $0.name }
        self.memberCount = detail.memberCount
        self.limitCount = detail.limitCount
        self.onlineCount = detail.onlineCount
        self.leaderName = detail.leaderName
        self.notice = detail.notice
        self.isOnline.onNext(detail.isOnline)
    }
}

// MARK: - api
private extension MyGroupDetailViewModel {
    func initFetchDetails(groupId: Int) {
        let groupDetailFetcher = useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchMyGroupDetailUseCase
                    .execute(token: token, groupId: groupId)
            }
        
        let membersFetcher = useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchMyGroupMemberListUseCase
                    .execute(token: token, groupId: groupId)
            }
        
        Single.zip(
            groupDetailFetcher,
            membersFetcher
        )
        .subscribe(onSuccess: { [weak self] (detail, members) in
            self?.setGroupDetail(detail: detail)
            self?.memberList = members
            
            self?.didFetchInfo.onNext(())
            if self?.mode == .notice {
                self?.didFetchNotice.onNext(())
                self?.didFetchMember.onNext(())
            }
        })
        .disposed(by: bag)
    }
    
    func fetchGroupDetail(groupId: Int) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchMyGroupDetailUseCase
                    .execute(token: token, groupId: groupId)
            }
            .subscribe(onSuccess: { [weak self] detail in
                self?.setGroupDetail(detail: detail)
                self?.didFetchInfo.onNext(())
                if self?.mode == .notice {
                    self?.didFetchNotice.onNext(())
                }
            })
            .disposed(by: bag)
    }
    
    func fetchMemberList(groupId: Int) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token in
                return self?.useCases.fetchMyGroupMemberListUseCase
                    .execute(token: token, groupId: groupId)
            }
            .subscribe(onSuccess: { [weak self] list in
                self?.memberList = list
                
                if self?.mode == .notice {
                    self?.didFetchMember.onNext(())
                }
            })
            .disposed(by: bag)
    }
    
    func fetchTodo(from: Date, to: Date) {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token -> Single<[Date: [TodoSummaryViewModel]]>? in
                guard let self else { return nil }
                return self.useCases.fetchMyGroupCalendarUseCase
                    .execute(token: token, groupId: self.groupId, from: from, to: to)
            }
            .subscribe(onSuccess: { [weak self] todoDict in
                guard let self else { return }
                self.todos = todoDict
                
                if self.mode == .calendar {
                    self.drawDailyViewModels()
                }
            })
            .disposed(by: bag)
    }
}

// MARK: Image Fetcher
extension MyGroupDetailViewModel {
    func fetchImage(key: String) -> Single<Data> {
        useCases
            .fetchImageUseCase
            .execute(key: key)
    }
    
    func withdrawGroup() {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token -> Single<Void>? in
                guard let self else { return nil }
                return self.useCases.withdrawGroupUseCase
                    .execute(token: token, groupId: self.groupId)
            }
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onSuccess: { [weak self] _ in
                self?.actions.pop?()
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.showMessage.onNext(Message(text: message, state: .warning))
            })
            .disposed(by: bag)
    }
}

// MARK: Calendar
private extension MyGroupDetailViewModel {
    func createCalendar(date: Date) {
        updateCurrentDate(date: date)
        mainDays = useCases.createMonthlyCalendarUseCase.execute(date: date)

        let startDate = mainDays.first?.date ?? Date()
        let endDate = mainDays.last?.date ?? Date()
        fetchTodo(from: startDate, to: endDate)
    }
    
    func updateCurrentDate(date: Date) {
        currentDate = date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 MM월"
        self.dateTitle = dateFormatter.string(from: date)
    }
}

// MARK: Online Actions
extension MyGroupDetailViewModel {
    func flipOnlineState() {
        useCases
            .executeWithTokenUseCase
            .execute() { [weak self] token -> Single<Void>? in
                guard let self else { return nil }
                return self.useCases.setOnlineUseCase
                    .execute(token: token, groupId: self.groupId)
            }
            .subscribe(onFailure: { [weak self] _ in
                self?.isOnline.onNext(try? self?.isOnline.value())
            })
            .disposed(by: bag)
    }
}

// MARK: - DailyViewModel 그리기
extension MyGroupDetailViewModel {
    func drawDailyViewModels() {
        todoStackingBuffer = [[Bool]](repeating: [Bool](repeating: false, count: 30), count: 42)
        (0..<mainDays.count).forEach { item in
            if item%7 == 0 {
                stackDailyViewModelOfWeek(at: IndexPath(item: item, section: 0))
            }
        }
        self.didFetchCalendar.onNext(())
    }
}

// MARK: VC쪽이 UI용 투두 ViewModel 준비를 위해 요청
extension MyGroupDetailViewModel {
    func stackDailyViewModelOfWeek(at indexPath: IndexPath) {
        let date = mainDays[indexPath.item].date
        if indexPath.item%7 == 0 {
            (indexPath.item..<indexPath.item + 7).forEach {
                todoStackingBuffer[$0] = [Bool](repeating: false, count: 30)
            }
            
            for (item, day) in Array(mainDays.enumerated())[indexPath.item..<indexPath.item + 7] {
                var todoList = todos[day.date] ?? []
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
    
    func getDayHeight(at indexPath: IndexPath) -> Int {
        let date = mainDays[indexPath.item].date
        guard let viewModel = dailyViewModels[date] else { return 0 }
        
        return viewModel.holiday != nil
        ? viewModel.holiday!.0 + 1 : viewModel.singleTodo.last != nil
        ? viewModel.singleTodo.last!.0 + 1 : viewModel.periodTodo.last != nil
        ? viewModel.periodTodo.last!.0 + 1 : 0
    }
    
    func maxCountDailyViewModelOfWeek(at indexPath: IndexPath) -> (Int, DailyViewModel?) {
        let weekRange = (indexPath.item - indexPath.item%7..<indexPath.item - indexPath.item%7 + 7)
        
        let result = weekRange.map { (index: Int) -> (Int, DailyViewModel?) in
            let date = mainDays[index].date
            return (getDayHeight(at: IndexPath(item: index, section: indexPath.section)), dailyViewModels[date])
        }.max { $0.0 < $1.0 }

        return result ?? (0, nil)
    }
}

// MARK: prepare TodosInDayViewModel
private extension MyGroupDetailViewModel {
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
        if let holidayTitle = HolidayPool.shared.holidays[mainDays[indexPath.item].date] {
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
        
        let date = mainDays[indexPath.item].date
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
