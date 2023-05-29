//
//  SearchResultViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/30.
//

import Foundation
import RxSwift

class SearchResultViewModel {
    
    var bag = DisposeBag()
    
    var actions: SearchHomeViewModelActions?
    
    var history: [String] = ["판교", "개발자", "스위프트", "건대", "N수"]
    var result: [UnJoinedGroupSummary] = []
    
    var keyword = BehaviorSubject<String?>(value: nil)
    
    var isLoading: Bool = false
    
    var didStartFetching = PublishSubject<Void>()
    var didFetchInitialResult = PublishSubject<Void>()
    var didFetchAdditionalResult = PublishSubject<Range<Int>>()
    var resultEnded = PublishSubject<Void>()
    var nonKeyword = PublishSubject<Void>()
    
    var page: Int = 0
    var size: Int = 5
    
    struct Input {
        var tappedItemAt: Observable<Int>
        var refreshRequired: Observable<Void>
        var keywordChanged: Observable<String?>
        var searchBtnTapped: Observable<Void>
        var createBtnTapped: Observable<Void>
        var needLoadNextData: Observable<Void>
    }
    
    struct Output {
        var didStartFetching: Observable<Void>
        var didFetchInitialResult: Observable<Void>
        var didFetchAdditionalResult: Observable<Range<Int>>
        var resultEnded: Observable<Void>
        var nonKeyword: Observable<Void>
    }
    
    let getTokenUseCase: GetTokenUseCase
    let refreshTokenUseCase: RefreshTokenUseCase
    let fetchSearchResultUseCase: FetchSearchResultUseCase
    let fetchImageUseCase: FetchImageUseCase
    
    init(
        getTokenUseCase: GetTokenUseCase,
        refreshTokenUseCase: RefreshTokenUseCase,
        fetchSearchResultUseCase: FetchSearchResultUseCase,
        fetchImageUseCase: FetchImageUseCase
    ) {
        self.getTokenUseCase = getTokenUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.fetchSearchResultUseCase = fetchSearchResultUseCase
        self.fetchImageUseCase = fetchImageUseCase
    }
    
    func setActions(actions: SearchHomeViewModelActions) {
        self.actions = actions
    }
    
    func transform(input: Input) -> Output {
        
        input
            .tappedItemAt
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                let groupId = vm.result[index].groupId
                vm.actions?.showGroupIntroducePage?(groupId)
            })
            .disposed(by: bag)
        
        input
            .refreshRequired
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                guard let keyword = try? vm.keyword.value(),
                      !keyword.isEmpty else {
                    return
                }
                vm.fetchInitialresult(keyword: keyword)
            })
            .disposed(by: bag)
        
        input
            .keywordChanged
            .bind(to: keyword)
            .disposed(by: bag)
        
        input.searchBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                guard let keyword = try? vm.keyword.value(),
                      !keyword.isEmpty else {
                    return
                }
                vm.fetchInitialresult(keyword: keyword)
            })
            .disposed(by: bag)
        
        input.createBtnTapped
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                vm.actions?.showGroupCreatePage?()
            })
            .disposed(by: bag)
        
        input.needLoadNextData
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                guard let keyword = try? vm.keyword.value(),
                      !keyword.isEmpty else {
                    return
                }
                vm.fetchResult(keyword: keyword, isInitial: false)
            })
            .disposed(by: bag)
        
        return Output(
            didStartFetching: didStartFetching.asObservable(),
            didFetchInitialResult: didFetchInitialResult.asObservable(),
            didFetchAdditionalResult: didFetchAdditionalResult.asObservable(),
            resultEnded: resultEnded.asObservable(),
            nonKeyword: nonKeyword.asObservable()
        )
    }
    
    func fetchInitialresult(keyword: String) {
        didStartFetching.onNext(())
        page = 0
        result.removeAll()
        fetchResult(keyword: keyword, isInitial: true)
    }
    
    func fetchResult(keyword: String, isInitial: Bool) {
        getTokenUseCase
            .execute()
            .flatMap { [weak self] token -> Single<[UnJoinedGroupSummary]> in
                guard let self else {
                    throw DefaultError.noCapturedSelf
                }
                return self.fetchSearchResultUseCase
                    .execute(token: token, keyWord: keyword, page: self.page, size: self.size)
            }
            .handleRetry(
                retryObservable: refreshTokenUseCase.execute(),
                errorType: TokenError.noTokenExist
            )
            .subscribe(onSuccess: { [weak self] list in
                guard let self else { return }
                print(self.page, self.size, list.count)
                self.result += list
                print(self.result)
                if isInitial {
                    self.didFetchInitialResult.onNext(())
                } else {
                    self.didFetchAdditionalResult.onNext((self.page * self.size..<self.page * self.size+list.count))
                }
                if list.count != self.size { //이럼 끝에 달한거임. 막아야함..!
                    self.resultEnded.onNext(())
                }
                self.page += 1
            })
            .disposed(by: bag)
    }
    
    func fetchImage(key: String) -> Single<Data> {
        fetchImageUseCase
            .execute(key: key)
    }
}

