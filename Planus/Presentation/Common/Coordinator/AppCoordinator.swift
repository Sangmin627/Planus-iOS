//
//  AppCoordinator.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/20.
//

import UIKit
import RxSwift

final class AppCoordinator: Coordinator {
    struct Dependency {
        let window: UIWindow
        let injector: Injector
    }
    
    var bag = DisposeBag()
        
    private let dependency: Dependency
        
    var childCoordinators: [Coordinator] = []
    var actionAfterSignInQueue: [() -> Void] = []
    weak var finishDelegate: CoordinatorFinishDelegate?

    var type: CoordinatorType = .app
            
    init(dependency: Dependency) {
        self.dependency = dependency
    }
    
    func start() {
        checkAutoSignIn()
    }
    
    private func checkAutoSignIn() {
        // 우선 여기서 자동로그인이 되있는지를 봐야한다..!
        let api = NetworkManager()
        let keyChain = KeyChainManager()
        
        let tokenRepo = DefaultTokenRepository(apiProvider: api, keyValueStorage: keyChain)
        let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
        let refreshTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
        let setTokenUseCase = DefaultSetTokenUseCase(tokenRepository: tokenRepo)

        getTokenUseCase
            .execute()
            .flatMap { _ in refreshTokenUseCase.execute() }
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onSuccess: { [weak self] token in
                guard let self else { return }
                self.showMainTabFlow()
                DispatchQueue.main.async {
                    while !self.actionAfterSignInQueue.isEmpty {
                        let action = self.actionAfterSignInQueue.removeFirst()
                        action()
                    }
                }
            }, onFailure: { [weak self] error in
                if let ne = error as? NetworkManagerError,
                   case NetworkManagerError.clientError(let int, let string) = ne {
                    print(string)
                }
                print("signIn!!")
                self?.showSignInFlow()
            })
            .disposed(by: bag)
        
        // 마지막으로 리프레시 된놈을 얻어와야한다..!
            
    }
    
    func showSignInFlow() {
        let navigation = UINavigationController()
        dependency.window.rootViewController = navigation

        let signInCoordinator = SignInCoordinator(navigationController: navigation)
        signInCoordinator.finishDelegate = self
        signInCoordinator.start()
        childCoordinators.removeAll()
        childCoordinators.append(signInCoordinator)
        
        dependency.window.makeKeyAndVisible()
    }
    
    func showMainTabFlow() {
        DispatchQueue.main.async { [weak self] in
            let navigation = UINavigationController()
            self?.dependency.window.rootViewController = navigation

            let tabCoordinator = MainTabCoordinator(navigationController: navigation)
            tabCoordinator.finishDelegate = self
            tabCoordinator.start()
            self?.childCoordinators.append(tabCoordinator)
            
            self?.dependency.window.makeKeyAndVisible()
            self?.viewTransitionAnimation()
            
//            self?.patchFCMToken()
        }
    }
    
    func viewTransitionAnimation() {
        UIView.transition(with: dependency.window,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil,
                          completion: nil)
    }

    func appendActionAfterAutoSignIn(action: @escaping () -> Void) {
        actionAfterSignInQueue.append(action)
    }
    
    func parseUniversalLink(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let paths = components.path.split(separator: "/")

        switch paths.first {
        case "groups":

            guard let groupIdString = components.queryItems?.first(where: { $0.name == "groupID"})?.value,
            let groupId = Int(groupIdString) else { return } //잘못된 링크
            let mainTabCoordinator = childCoordinators.first(where: { $0 is MainTabCoordinator }) as? MainTabCoordinator
            mainTabCoordinator?.setTabBarControllerPage(page: .search)
            let searchCoordinator = mainTabCoordinator?.childCoordinators.first(where: { $0 is SearchCoordinator }) as? SearchCoordinator
            searchCoordinator?.showGroupIntroducePage(groupId)
        default: break
        }
    }
    
    func patchFCMToken() {
        let api = NetworkManager()
        let keyChainManager = KeyChainManager()
        let tokenRepo = DefaultTokenRepository(apiProvider: api, keyValueStorage: keyChainManager)
        let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
        let refreshTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
        let fcmRepo = DefaultFCMRepository(apiProvider: NetworkManager(), keyValueStorage: UserDefaultsManager())

        getTokenUseCase
            .execute()
            .flatMap { token -> Single<Void> in
                fcmRepo.patchFCMToken(token: token.accessToken).map { _ in () }
            }
            .handleRetry(
                retryObservable: refreshTokenUseCase.execute(),
                errorType: NetworkManagerError.tokenExpired
            )
            .subscribe(onSuccess: { _ in
                print("fcm patch success")
            }, onFailure: { error in
                print(error)
            })
            .disposed(by: bag)
    }
}

extension AppCoordinator: CoordinatorFinishDelegate {
    func coordinatorDidFinish(childCoordinator: Coordinator) {
        childCoordinators = childCoordinators.filter {
            $0.type != childCoordinator.type
        }
    }
}
