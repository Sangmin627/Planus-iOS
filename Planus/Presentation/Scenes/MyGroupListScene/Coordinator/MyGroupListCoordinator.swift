//
//  MyGroupListCoordinator.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/22.
//

import UIKit

final class MyGroupListCoordinator: Coordinator {
    
    struct Dependency {
        let navigationController: UINavigationController
        let injector: Injector
    }
    
    let dependency: Dependency
    
    weak var finishDelegate: CoordinatorFinishDelegate?
    var childCoordinators: [Coordinator] = []
    var type: CoordinatorType = .myGroupList

    init(dependency: Dependency) {
        self.dependency = dependency
    }
    
    func start() {
        showGroupListPage()
    }
    
    lazy var showGroupListPage: () -> Void = { [weak self] in
        guard let self else { return }
        
        let vm = self.dependency.injector.resolve(
            MyGroupListViewModel.self,
            injectable: MyGroupListViewModel.Injectable(
                actions: .init(
                    showGroupDetailPage: self.showGroupDetailPage,
                    showNotificationPage: self.showNotificationPage
                ),
                args: .init()
            )
        )
        
        let vc = MyGroupListViewController(viewModel: vm)
        
        self.dependency.navigationController.pushViewController(vc, animated: true)
    }

    lazy var showGroupDetailPage: (Int) -> Void = { [weak self] groupId in
        guard let self else { return }
        let coordinator = MyGroupDetailCoordinator(
            dependency: MyGroupDetailCoordinator.Dependency(
                navigationController: self.dependency.navigationController,
                injector: self.dependency.injector
            )
        )
        coordinator.finishDelegate = self
        self.childCoordinators.append(coordinator)
        coordinator.start(groupId: groupId)
    }
    
    lazy var showNotificationPage: () -> Void = { [weak self] in
        guard let self else { return }
        let coordinator = NotificationCoordinator(
            dependency: NotificationCoordinator.Dependency(
                navigationController: self.dependency.navigationController,
                injector: self.dependency.injector
            )
        )
        coordinator.finishDelegate = self
        self.childCoordinators.append(coordinator)
        coordinator.start()
    }
}

extension MyGroupListCoordinator: CoordinatorFinishDelegate {
    func coordinatorDidFinish(childCoordinator: Coordinator) {
        childCoordinators = childCoordinators.filter {
            $0.type != childCoordinator.type
        }
    }
}

