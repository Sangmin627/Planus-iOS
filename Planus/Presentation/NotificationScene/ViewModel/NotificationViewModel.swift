//
//  NotificationViewModel.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/09.
//

import Foundation
import RxSwift

class NotificationViewModel {
    var bag = DisposeBag()
    
    struct Input {
        var viewDidLoad: Observable<Void>
        var didTapAllowBtnAt: Observable<Int?>
        var didTapDenyBtnAt: Observable<Int?>
        var refreshRequired: Observable<Void>
    }
    
    struct Output {
        var didFetchJoinApplyList: Observable<FetchType?>
        var needRemoveAt: Observable<Int>
        var showMessage: Observable<Message>
    }
    
    var joinAppliedList: [GroupJoinApplied]?
    var nowProcessingJoinId: [Int] = []
    var didFetchJoinApplyList = BehaviorSubject<FetchType?>(value: nil)
    var needRemoveAt = PublishSubject<Int>()
    
    var showMessage = PublishSubject<Message>()
    
    var getTokenUseCase: GetTokenUseCase
    var refreshTokenUseCase: RefreshTokenUseCase
    var setTokenUseCase: SetTokenUseCase
    var fetchJoinApplyListUseCase: FetchJoinApplyListUseCase
    var fetchImageUseCase: FetchImageUseCase
    var acceptGroupJoinUseCase: AcceptGroupJoinUseCase
    var denyGroupJoinUseCase: DenyGroupJoinUseCase
    
    init(
        getTokenUseCase: GetTokenUseCase,
        refreshTokenUseCase: RefreshTokenUseCase,
        setTokenUseCase: SetTokenUseCase,
        fetchJoinApplyListUseCase: FetchJoinApplyListUseCase,
        fetchImageUseCase: FetchImageUseCase,
        acceptGroupJoinUseCase: AcceptGroupJoinUseCase,
        denyGroupJoinUseCase: DenyGroupJoinUseCase
    ) {
        self.getTokenUseCase = getTokenUseCase
        self.refreshTokenUseCase = refreshTokenUseCase
        self.setTokenUseCase = setTokenUseCase
        self.fetchJoinApplyListUseCase = fetchJoinApplyListUseCase
        self.fetchImageUseCase = fetchImageUseCase
        self.acceptGroupJoinUseCase = acceptGroupJoinUseCase
        self.denyGroupJoinUseCase = denyGroupJoinUseCase
    }
    
    func transform(input: Input) -> Output {
        input
            .viewDidLoad
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    vm.fetchJoinApplyList(fetchType: .initail)
                })
            })
            .disposed(by: bag)
        
        input
            .didTapAllowBtnAt
            .compactMap { $0 }
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                vm.acceptGroupJoinAt(index: index)
            })
            .disposed(by: bag)
        
        input
            .didTapDenyBtnAt
            .compactMap { $0 }
            .withUnretained(self)
            .subscribe(onNext: { vm, index in
                vm.denyGroupJoinAt(index: index)
            })
            .disposed(by: bag)
        
        input
            .refreshRequired
            .withUnretained(self)
            .subscribe(onNext: { vm, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    vm.fetchJoinApplyList(fetchType: .refresh)
                })
            })
            .disposed(by: bag)
        
        return Output(
            didFetchJoinApplyList: didFetchJoinApplyList.asObservable(),
            needRemoveAt: needRemoveAt.asObservable(),
            showMessage: showMessage.asObservable()
        )
    }
    
    func acceptGroupJoinAt(index: Int) {
        guard let id = joinAppliedList?[index].groupJoinId,
              nowProcessingJoinId.filter({ $0 == id }).isEmpty else { return }
        nowProcessingJoinId.append(id)
        getTokenUseCase
            .execute()
            .flatMap { [weak self] token -> Single<Void> in
                guard let self else {
                    throw DefaultError.noCapturedSelf
                }
                return self.acceptGroupJoinUseCase
                    .execute(token: token, applyId: id)
            }
            .handleRetry(
                retryObservable: refreshTokenUseCase.execute(),
                errorType: NetworkManagerError.tokenExpired
            )
            .subscribe(onSuccess: { [weak self] _ in
                self?.nowProcessingJoinId.removeAll(where: { $0 == id })
                self?.joinAppliedList?.remove(at: index)
                self?.needRemoveAt.onNext(index)
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.showMessage.onNext(Message(text: message, state: .warning))
                self?.nowProcessingJoinId.removeAll(where: { $0 == id })
            })
            .disposed(by: bag)
    }
    
    func denyGroupJoinAt(index: Int) {
        guard let id = joinAppliedList?[index].groupJoinId,
              nowProcessingJoinId.filter({ $0 == id }).isEmpty else { return }
        nowProcessingJoinId.append(id)
        getTokenUseCase
            .execute()
            .flatMap { [weak self] token -> Single<Void> in
                guard let self else {
                    throw DefaultError.noCapturedSelf
                }
                return self.denyGroupJoinUseCase
                    .execute(token: token, applyId: id)
            }
            .handleRetry(
                retryObservable: refreshTokenUseCase.execute(),
                errorType: NetworkManagerError.tokenExpired
            )
            .subscribe(onSuccess: { [weak self] _ in
                self?.nowProcessingJoinId.removeAll(where: { $0 == id })
                self?.joinAppliedList?.remove(at: index)
                self?.needRemoveAt.onNext(index)
            }, onFailure: { [weak self] error in
                guard let error = error as? NetworkManagerError,
                      case NetworkManagerError.clientError(let status, let message) = error,
                      let message = message else { return }
                self?.showMessage.onNext(Message(text: message, state: .warning))
                self?.nowProcessingJoinId.removeAll(where: { $0 == id })
            })
            .disposed(by: bag)
    }
    
    func fetchJoinApplyList(fetchType: FetchType) {
        getTokenUseCase
            .execute()
            .flatMap { [weak self] token -> Single<[GroupJoinApplied]> in
                guard let self else {
                    throw DefaultError.noCapturedSelf
                }
                return self.fetchJoinApplyListUseCase
                    .execute(token: token)
            }
            .handleRetry(
                retryObservable: refreshTokenUseCase.execute(),
                errorType: NetworkManagerError.tokenExpired
            )
            .subscribe(onSuccess: { [weak self] list in
                self?.joinAppliedList = list
                self?.didFetchJoinApplyList.onNext((fetchType))
            })
            .disposed(by: bag)
    }
    
    func fetchImage(key: String) -> Single<Data> {
        fetchImageUseCase
            .execute(key: key)
    }
    
}
