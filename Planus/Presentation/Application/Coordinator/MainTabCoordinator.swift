//
//  MainTabCoordinator.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/20.
//

import UIKit

enum TabBarPage: Int, CaseIterable {
    case calendar = 0
    case search
    case group
    
    func pageTitleValue() -> String {
        switch self {
        case .calendar:
            return "캘린더"
        case .search:
            return "검색"
        case .group:
            return "그룹"
        }
    }
    
    func pageTabIcon() -> UIImage? {
        switch self {
        case .calendar:
            return UIImage(named: "calendarTab")
        case .search:
            return UIImage(named: "searchTab")
        case .group:
            return UIImage(named: "groupTab")
        }
    }
}

final class MainTabCoordinator: NSObject, Coordinator {
    
    struct Dependency {
        let navigationController: UINavigationController
        let injector: Injector
    }
        
    let dependency: Dependency
    weak var finishDelegate: CoordinatorFinishDelegate?
        
    private var tabBarController: UITabBarController
    var childCoordinators: [Coordinator] = []
    var type: CoordinatorType = .mainTab
    
    private var currentPage: TabBarPage = .calendar
    
    init(dependency: Dependency) {
        self.dependency = dependency
        self.tabBarController = UITabBarController()
    }
    
    func start() {
        let pages = TabBarPage.allCases
        let controllers: [UINavigationController] = pages.map { getTabController($0) }
        dependency.navigationController.setNavigationBarHidden(true, animated: false)
        prepareTabBarController(withTabControllers: controllers)
    }
    
    func setTabBarControllerPage(page: TabBarPage) {
        currentPage = page
        tabBarController.selectedIndex = page.rawValue
    }
    
    private func prepareTabBarController(withTabControllers tabControllers: [UIViewController]) {
        tabBarController.setViewControllers(tabControllers, animated: true)
        tabBarController.selectedIndex = TabBarPage.calendar.rawValue
        
        tabBarController.tabBar.layer.masksToBounds = false
        tabBarController.tabBar.layer.shadowColor = UIColor.planusBlack.cgColor
        tabBarController.tabBar.layer.shadowOpacity = 0.6
        tabBarController.tabBar.layer.shadowOffset = CGSize(width: 0, height: 2)
        tabBarController.tabBar.layer.shadowRadius = 5
        
        tabBarController.tabBar.barTintColor = .planusWhite
        tabBarController.tabBar.isTranslucent = false
        tabBarController.delegate = self
        
        self.tabBarController.tabBar.backgroundColor = .planusBackgroundColor

        self.tabBarController.tabBar.tintColor = .planusBlack
        self.tabBarController.tabBar.unselectedItemTintColor = .planusLightGray
        
        dependency.navigationController.viewControllers = [tabBarController]
    }
    
    private func getTabController(_ page: TabBarPage) -> UINavigationController {
        let navigation = UINavigationController()
        
        navigation.tabBarItem = UITabBarItem.init(
            title: page.pageTitleValue(),
            image: page.pageTabIcon(),
            tag: page.rawValue
        )


        switch page {
        case .calendar:
            let homeCalendarCoordinator = HomeCalendarCoordinator(
                dependency: HomeCalendarCoordinator.Dependency(
                    navigationController: navigation,
                    injector: dependency.injector
                )
            )
            homeCalendarCoordinator.finishDelegate = self
            childCoordinators.append(homeCalendarCoordinator)
            homeCalendarCoordinator.start()
        case .search:
            let searchCoordinator = SearchCoordinator(
                dependency: SearchCoordinator.Dependency(
                    navigationController: navigation,
                    injector: dependency.injector
                )
            )
            searchCoordinator.finishDelegate = self
            childCoordinators.append(searchCoordinator)
            searchCoordinator.start()
        case .group:
            let groupCoordinator = MyGroupListCoordinator(
                dependency: MyGroupListCoordinator.Dependency(
                    navigationController: navigation,
                    injector: dependency.injector
                )
            )
            groupCoordinator.finishDelegate = self
            childCoordinators.append(groupCoordinator)
            groupCoordinator.start()
        }
        
        return navigation
    }
}

extension MainTabCoordinator: CoordinatorFinishDelegate {
    func coordinatorDidFinish(childCoordinator: Coordinator) {
        childCoordinators = childCoordinators.filter {
            $0.type != childCoordinator.type
        }
    }
}

extension MainTabCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if tabBarController.selectedIndex == currentPage.rawValue {
            childCoordinators[tabBarController.selectedIndex].childCoordinators = []
            
            if currentPage == .calendar {
                guard let coordinator = childCoordinators[0] as? HomeCalendarCoordinator else { return }
                coordinator.homeTapReselected.onNext(())
            }
        } else {
            guard let newPage = TabBarPage(rawValue: tabBarController.selectedIndex) else { return }
            currentPage = newPage
        }
        
    }
}
