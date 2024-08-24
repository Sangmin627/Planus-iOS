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
        showInitialPage()
//        checkAutoSignIn()
    }
    
    private func showInitialPage() {
        let vc = InitialViewController()
        vc.delegate = self
        dependency.window.rootViewController = vc
        dependency.window.makeKeyAndVisible()
        self.viewTransitionAnimation()
    }
    
    private func checkAutoSignIn() {
        let getTokenUseCase = dependency.injector.resolve(GetTokenUseCase.self)
        let refreshTokenUseCase = dependency.injector.resolve(RefreshTokenUseCase.self)
        
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
                   case NetworkManagerError.clientError(_, let string) = ne {
                    print(string as Any)
                }
                self?.showSignInFlow()
            })
            .disposed(by: bag)
                    
    }
    
    func showSignInFlow() {
        let navigation = UINavigationController()
        dependency.window.rootViewController = navigation
        
        let signInCoordinator = SignInCoordinator(
            dependency: .init(
                navigationController: navigation,
                injector: self.dependency.injector
            )
        )
        
        signInCoordinator.finishDelegate = self
        signInCoordinator.start()
        childCoordinators.removeAll()
        childCoordinators.append(signInCoordinator)
        
        dependency.window.makeKeyAndVisible()
        self.viewTransitionAnimation()
    }
    
    func showMainTabFlow() {
        let navigation = UINavigationController()
        self.dependency.window.rootViewController = navigation
        
        let tabCoordinator = MainTabCoordinator(dependency: MainTabCoordinator.Dependency(navigationController: navigation, injector: self.dependency.injector))
        tabCoordinator.finishDelegate = self
        tabCoordinator.start()
        self.childCoordinators.append(tabCoordinator)
        
        self.dependency.window.makeKeyAndVisible()
        self.viewTransitionAnimation()
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
            let groupId = Int(groupIdString) else { return }
            let mainTabCoordinator = childCoordinators.first(where: { $0 is MainTabCoordinator }) as? MainTabCoordinator
            mainTabCoordinator?.setTabBarControllerPage(page: .search)
            let searchCoordinator = mainTabCoordinator?.childCoordinators.first(where: { $0 is SearchCoordinator }) as? SearchCoordinator
            searchCoordinator?.showGroupIntroducePage(groupId)
        default: break
        }
    }
    
    func patchFCMToken() {
        let executeWithTokenUseCase = dependency.injector.resolve(ExecuteWithTokenUseCase.self)
        let fcmRepo = dependency.injector.resolve(FCMRepository.self)

        executeWithTokenUseCase
            .execute() { token -> Single<Void>? in
                fcmRepo.patchFCMToken(token: token.accessToken).map { _ in () }
            }
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

extension AppCoordinator: InitDelegate {
    func fin() {
        checkAutoSignIn()
    }
}
