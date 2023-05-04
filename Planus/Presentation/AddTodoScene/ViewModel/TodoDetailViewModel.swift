//
//  TodoDetailViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/28.
//

import Foundation
import RxSwift

enum CategoryCreateState {
    case new
    case edit(Int)
}

final class TodoDetailViewModel {
    var bag = DisposeBag()
    
    var completionHandler: ((Todo) -> Void)?
    
    var categoryColorList: [CategoryColor] = Array(CategoryColor.allCases[0..<CategoryColor.allCases.count-1])
    
    var categorys: [Category] = []
    var groups: [Group] = []
    
    var categoryCreatingState: CategoryCreateState = .new
    
    var todoTitle = BehaviorSubject<String?>(value: nil)
    var todoCategory = BehaviorSubject<Category?>(value: nil)
    var todoStartDay = BehaviorSubject<Date?>(value: nil)
    var todoEndDay: Date?
    var todoGroup = BehaviorSubject<Group?>(value: nil)
    var todoMemo = BehaviorSubject<String?>(value: nil)
    
    var needDismiss = PublishSubject<Void>()
    
    var newCategoryName = BehaviorSubject<String?>(value: nil)
    var newCategoryColor = BehaviorSubject<CategoryColor?>(value: nil)
    
    var groupListChanged = PublishSubject<Void>()
    
    let moveFromAddToSelect = PublishSubject<Void>()
    let moveFromSelectToCreate = PublishSubject<Void>()
    let moveFromCreateToSelect = PublishSubject<Void>()
    let moveFromSelectToAdd = PublishSubject<Void>()
    let needReloadCategoryList = PublishSubject<Void>()
    let removeKeyboard = PublishSubject<Void>()
    
    struct Input {
        // MARK: Control Value
        var todoTitleChanged: Observable<String?>
        var categorySelected: Observable<Int?>
        var startDayChanged: Observable<Date?>
        var endDayChanged: Observable<Date?>
        var groupSelected: Observable<Int?>
        var memoChanged: Observable<String?>
        var newCategoryNameChanged: Observable<String?>
        var newCategoryColorChanged: Observable<CategoryColor?>
        
        // MARK: Control Event
        var categoryEditRequested: Observable<Int>
        var startDayButtonTapped: Observable<Void>
        var endDayButtonTapped: Observable<Void>
        var categorySelectBtnTapped: Observable<Void>
        var todoSaveBtnTapped: Observable<Void>
        var newCategoryAddBtnTapped: Observable<Void>
        var newCategorySaveBtnTapped: Observable<Void>
        var categorySelectPageBackBtnTapped: Observable<Void>
        var categoryCreatePageBackBtnTapped: Observable<Void>
    }
    
    struct Output {
        var categoryChanged: Observable<Category?>
        var todoSaveBtnEnabled: Observable<Bool>
        var newCategorySaveBtnEnabled: Observable<Bool>
        var newCategorySaved: Observable<Void>
        var moveFromAddToSelect: Observable<Void>
        var moveFromSelectToCreate: Observable<Void>
        var moveFromCreateToSelect: Observable<Void>
        var moveFromSelectToAdd: Observable<Void>
        var removeKeyboard: Observable<Void>
        var needDismiss: Observable<Void>
    }
    
    var getTokenUseCase: GetTokenUseCase
    var refreshTokenUseCase: RefreshTokenUseCase
    var createTodoUseCase: CreateTodoUseCase
    var createCategoryUseCase: CreateCategoryUseCase
    var updateCategoryUseCase: UpdateCategoryUseCase
    var deleteCategoryUseCase: DeleteCategoryUseCase
    var readCategoryUseCase: ReadCategoryListUseCase
    
    init(
        getTokenUseCase: GetTokenUseCase,
        refreshTokenUseCase: RefreshTokenUseCase,
        createTodoUseCase: CreateTodoUseCase,
        createCategoryUseCase: CreateCategoryUseCase,
        updateCategoryUseCase: UpdateCategoryUseCase,
        deleteCategoryUseCase: DeleteCategoryUseCase,
        readCategoryUseCase: ReadCategoryListUseCase
    ) {
        self.getTokenUseCase = getTokenUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.createTodoUseCase = createTodoUseCase
        self.createCategoryUseCase = createCategoryUseCase
        self.updateCategoryUseCase = updateCategoryUseCase
        self.deleteCategoryUseCase = deleteCategoryUseCase
        self.readCategoryUseCase = readCategoryUseCase
    }
    
    public func transform(input: Input) -> Output {
        
        fetchCategoryList()
        fetchGroupList()
        
        input
            .todoTitleChanged
            .bind(to: todoTitle)
            .disposed(by: bag)
        
        input
            .categorySelected
            .compactMap { $0 }
            .withUnretained(self)
            .map { vm, index in
                return vm.categorys[index]
            }
            .bind(to: todoCategory)
            .disposed(by: bag)
        
        input
            .startDayChanged
            .bind(to: todoStartDay)
            .disposed(by: bag)
        
        input
            .endDayChanged
            .withUnretained(self)
            .subscribe(onNext: { vm, date in
                vm.todoEndDay = date
            })
            .disposed(by: bag)
        
        input
            .groupSelected
            .compactMap { $0 }
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                vm.todoGroup.onNext(vm.groups[index])
            })
            .disposed(by: bag)
        
        input
            .memoChanged
            .bind(to: todoMemo)
            .disposed(by: bag)
        
        input
            .newCategoryNameChanged
            .bind(to: newCategoryName)
            .disposed(by: bag)
        
        input
            .newCategoryColorChanged
            .bind(to: newCategoryColor)
            .disposed(by: bag)
        
        input
            .categoryEditRequested
            .withUnretained(self)
            .subscribe(onNext: { vm, id in
                guard let category = vm.categorys.first(where: { $0.id == id }) else { return }
                vm.categoryCreatingState = .edit(id)

                vm.newCategoryName.onNext(category.title)
                vm.newCategoryColor.onNext(category.color)
                vm.moveFromSelectToCreate.onNext(())
            })
            .disposed(by: bag)
        
        input
            .categorySelectBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.moveFromAddToSelect.onNext(())
            })
            .disposed(by: bag)
        
        input
            .todoSaveBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                guard let title = try? vm.todoTitle.value(),
                      let startDate = try? vm.todoStartDay.value(),
                      let categoryId = (try? vm.todoCategory.value())?.id else { return }
                let memo = try? vm.todoMemo.value()
                let todo = Todo(
                    id: nil,
                    title: title,
                    startDate: startDate,
                    endDate: vm.todoEndDay ?? startDate,
                    memo: memo,
                    groupId: nil,
                    categoryId: categoryId,
                    startTime: nil
                )
                vm.createTodo(todo: todo)
            })
            .disposed(by: bag)
        
        input
            .newCategoryAddBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.categoryCreatingState = .new
                vm.moveFromSelectToCreate.onNext(())
            })
            .disposed(by: bag)
        
        input
            .newCategorySaveBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                // 1. save current edit or creating
                guard let title = try? vm.newCategoryName.value(),
                      let color = try? vm.newCategoryColor.value() else { return }
                switch vm.categoryCreatingState {
                case .new:
                    vm.saveNewCategory(category: Category(id: nil, title: title, color: color))
                case .edit(let id):
                    vm.updateCategory(category: Category(id: id, title: title, color: color))
                }
            })
            .disposed(by: bag)
        
        input
            .categorySelectPageBackBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.moveFromSelectToAdd.onNext(())
            })
            .disposed(by: bag)
        
        input
            .categoryCreatePageBackBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.moveFromCreateToSelect.onNext(())
            })
            .disposed(by: bag)
        
        input
            .startDayButtonTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.removeKeyboard.onNext(())
            })
            .disposed(by: bag)
        
        input
            .endDayButtonTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.removeKeyboard.onNext(())
            })
            .disposed(by: bag)
        
        let todoSaveBtnEnabled = Observable
            .combineLatest(
                todoTitle,
                todoCategory,
                todoStartDay
            )
            .map { (title, category, startDay) in
                guard let title,
                      let category,
                      let startDay else { return false }
                
                return !title.isEmpty
            }
        
        let newCategorySaveBtnEnabled = Observable
            .combineLatest(
                newCategoryName,
                newCategoryColor
            )
            .map { (name, color) in
                guard let name,
                      let color else { return false }
                return !name.isEmpty
            }
        
        return Output(
            categoryChanged: todoCategory.asObservable(),
            todoSaveBtnEnabled: todoSaveBtnEnabled.asObservable(),
            newCategorySaveBtnEnabled: newCategorySaveBtnEnabled.asObservable(),
            newCategorySaved: needReloadCategoryList.asObservable(),
            moveFromAddToSelect: moveFromAddToSelect.asObservable(),
            moveFromSelectToCreate: moveFromSelectToCreate.asObservable(),
            moveFromCreateToSelect: moveFromCreateToSelect.asObservable(),
            moveFromSelectToAdd: moveFromSelectToAdd.asObservable(),
            removeKeyboard: removeKeyboard.asObservable(),
            needDismiss: needDismiss.asObservable()
        )
    }
    
    func fetchCategoryList() {
        guard let token = getTokenUseCase.execute() else { return }
        readCategoryUseCase
            .execute(token: token)
            .subscribe(onSuccess: { [weak self] list in
                self?.categorys = list
                self?.needReloadCategoryList.onNext(())
                print(self?.categorys)
            })
            .disposed(by: bag)
    }
    
    func fetchGroupList() {
        guard let token = getTokenUseCase.execute() else { return }
        
    }
    
    func createTodo(todo: Todo) {
        guard let token = getTokenUseCase.execute() else { return }
        
        createTodoUseCase
            .execute(token: token, todo: todo)
            .subscribe(onSuccess: { [weak self] id in
                var todoWithId = todo
                todoWithId.id = id
                self?.completionHandler?(todoWithId)
                self?.needDismiss.onNext(())
            })
            .disposed(by: bag)
    }

    func saveNewCategory(category: Category) {
        guard let token = getTokenUseCase.execute() else { return }
        createCategoryUseCase
            .execute(token: token, category: category)
            .subscribe(onSuccess: { [weak self] id in
                var categoryWithId = category
                categoryWithId.id = id

                self?.categorys.append(categoryWithId)
                self?.needReloadCategoryList.onNext(())
                self?.moveFromCreateToSelect.onNext(())
            })
            .disposed(by: bag)
    }
    
    func updateCategory(category: Category) {
        guard let token = getTokenUseCase.execute(),
              let id = category.id else { return }
        
        updateCategoryUseCase
            .execute(token: token, id: id, category: category)
            .subscribe(onSuccess: { [weak self] id in
                guard let index = self?.categorys.firstIndex(where: { $0.id == id }) else { return }
                self?.categorys[index] = category
                self?.needReloadCategoryList.onNext(())
                self?.moveFromCreateToSelect.onNext(())
            }, onFailure: { error in
                print(error)
            })
            .disposed(by: bag)
    }
    
    func deleteCategory(category: Category) {
        guard let id = category.id,
              let token = getTokenUseCase.execute() else { return }
        
        deleteCategoryUseCase
            .execute(token: token, id: id)
            .subscribe(onSuccess: { [weak self] in
                
            })
            .disposed(by: bag)
    }
}
