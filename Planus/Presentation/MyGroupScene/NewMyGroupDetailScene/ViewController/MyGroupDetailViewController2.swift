//
//  MyGroupDetailViewController2.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/22.
//

import UIKit
import RxSwift

extension MyGroupDetailMode {
    var imageTitle: String {
        switch self {
        case .dot:
            return "menuShowBtn"
        case .notice:
            return "NoticeCircleBtn"
        case .calendar:
            return "CalendarCircleBtn"
        case .chat:
            return "ChatCircleBtn"
        }
    }
}

class MyGroupDetailViewController2: UIViewController, UIGestureRecognizerDelegate {
    var bag = DisposeBag()
    
    let didChangedMonth = PublishSubject<Date>()
    var didSelectedDayAt = PublishSubject<Int>()
    var didSelectedMemberAt = PublishSubject<Int>()
    var didTappedOnlineButton = PublishSubject<Void>()
    
    static let headerElementKind = "my-group-detail-view-controller-header-kind"
    
    var nowLoading: Bool = true
    var didTappedButtonAt = PublishSubject<Int>()
    
    
    let initialTrailing: CGFloat = -27
    let targetTrailing: CGFloat = 20
    var firstXOffset: CGFloat?
    
    lazy var buttonList: [UIButton] = {
        return MyGroupDetailMode.allCases.map { [weak self] in
            let image = UIImage(named: $0.imageTitle) ?? UIImage()
            let button = SpringableButton(frame: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            button.setImage(image, for: .normal)
            button.tag = $0.rawValue
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            return button
        }
    }()
    
    var swipeBar: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "swipeBarLeft"))
        imageView.contentMode = .scaleToFill
        imageView.backgroundColor = .blue
        return imageView
    }()

    var buttonsView: AnimatedStrechButtonListView = {
        let stretchButtonView = AnimatedStrechButtonListView(axis: .up)
        return stretchButtonView
    }()
    
    var viewModel: MyGroupDetailViewModel2?
    
    lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout())

        cv.register(GroupIntroduceNoticeCell.self,
            forCellWithReuseIdentifier: GroupIntroduceNoticeCell.reuseIdentifier)
        
        cv.register(JoinedGroupMemberCell.self,
            forCellWithReuseIdentifier: JoinedGroupMemberCell.reuseIdentifier)
        
        cv.register(GroupIntroduceDefaultHeaderView.self,
                    forSupplementaryViewOfKind: Self.headerElementKind,
                    withReuseIdentifier: GroupIntroduceDefaultHeaderView.reuseIdentifier)
        
        cv.register(MyGroupInfoHeaderView.self,
                    forSupplementaryViewOfKind: Self.headerElementKind,
                    withReuseIdentifier: MyGroupInfoHeaderView.reuseIdentifier)
        
        cv.register(DailyCalendarCell.self, forCellWithReuseIdentifier: DailyCalendarCell.identifier)
        cv.register(JoinedGroupDetailCalendarHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: JoinedGroupDetailCalendarHeaderView.reuseIdentifier)
        
        cv.register(MyGroupDetailLoadingCell.self, forCellWithReuseIdentifier: MyGroupDetailLoadingCell.reuseIdentifier)
        
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColor = UIColor(hex: 0xF5F5FB)
        return cv
    }()
    
    lazy var backButton: UIBarButtonItem = {
        let image = UIImage(named: "back")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(backBtnAction))
        item.tintColor = .black
        return item
    }()
    
    lazy var shareButton: UIBarButtonItem = {
        let image = UIImage(named: "share")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(shareBtnAction))
        item.tintColor = .black
        return item
    }()
    
    convenience init(viewModel: MyGroupDetailViewModel2) {
        self.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureView()
        configureLayout()
        configureGestureRecognizer()
        
        bind()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.setLeftBarButton(backButton, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = self

        let initialAppearance = UINavigationBarAppearance()
        let scrollingAppearance = UINavigationBarAppearance()
        scrollingAppearance.configureWithOpaqueBackground()
        scrollingAppearance.backgroundColor = UIColor(hex: 0xF5F5FB)
        let initialBarButtonAppearance = UIBarButtonItemAppearance()
        initialBarButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        initialAppearance.configureWithTransparentBackground()
        initialAppearance.buttonAppearance = initialBarButtonAppearance
        
        let scrollingBarButtonAppearance = UIBarButtonItemAppearance()
        scrollingBarButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
        scrollingAppearance.buttonAppearance = scrollingBarButtonAppearance
        self.navigationItem.standardAppearance = scrollingAppearance
        self.navigationItem.scrollEdgeAppearance = initialAppearance
        
        self.navigationController?.navigationBar.standardAppearance = scrollingAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = initialAppearance
    }
        
    func bind() {
        guard let viewModel else { return }
        
        let input = MyGroupDetailViewModel2.Input(
            viewDidLoad: Observable.just(()),
            didTappedModeBtnAt: didTappedButtonAt.asObservable(),
            didChangedMonth: didChangedMonth.asObservable(),
            didSelectedDayAt: didSelectedDayAt.asObservable(),
            didSelectedMemberAt: didSelectedMemberAt.asObservable(),
            didTappedOnlineButton: didTappedOnlineButton.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        output
            .showMessage
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, message in
                vc.showToast(message: message.text, type: Message.toToastType(state: message.state))
            })
            .disposed(by: bag)
        
        output //한번에 말고,,, 먼저 오는거 순으로 패치하는게 맞나?? - 그럼 멤버가 먼저와도 이상함. 위에꺼 패치 후 멤버 패치해야하나?
            .didInitialFetch
            .take(1)
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                print("all")
                vc.nowLoading = false
                
                vc.swipeBar.setAnimatedIsHidden(false, duration: 0.2)
                
                vc.collectionView.performBatchUpdates {
                    vc.collectionView.reloadSections(IndexSet(0...1))
                    if vc.collectionView.numberOfSections == 2 {
                        vc.collectionView.insertSections(IndexSet(integer: 2))
                    } else {
                        vc.collectionView.reloadSections(IndexSet(integer: 2))
                    }
                }
            })
            .disposed(by: self.bag)
        
        
        
        output
            .didFetchInfo
            .compactMap { $0 }
            .skip(1)
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                print("info")
                vc.nowLoading = false
                vc.collectionView.reloadSections(IndexSet(integer: 0))
            })
            .disposed(by: bag)
        
        output
            .didFetchNotice
            .compactMap { $0 }
            .skip(1)
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                print("notice")
                vc.nowLoading = false
                vc.collectionView.performBatchUpdates({
                    if vc.collectionView.numberOfSections == 2 {
                        vc.collectionView.insertSections(IndexSet(integer: 2))
                    }
                    vc.collectionView.reloadSections(IndexSet(integer: 1))
                }, completion: { _ in
                    vc.collectionView.scrollToItem(at: IndexPath(item: 0, section: 1), at: .top, animated: true)
                })
            })
            .disposed(by: bag)
        
        output
            .didFetchMember
            .compactMap { $0 }
            .skip(1)
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                print("member")
                vc.nowLoading = false
                vc.collectionView.performBatchUpdates({
                    if vc.collectionView.numberOfSections == 2 {
                        vc.collectionView.insertSections(IndexSet(integer: 2))
                    } else if vc.collectionView.numberOfSections == 3 {
                        vc.collectionView.reloadSections(IndexSet(integer: 2))
                    }
                }, completion: { _ in
                    vc.collectionView.scrollToItem(at: IndexPath(item: 0, section: 1), at: .top, animated: true)
                })
            })
            .disposed(by: bag)
        
        output
            .didFetchCalendar
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                print("calendar")
                vc.nowLoading = false
                vc.collectionView.performBatchUpdates ({
                    if vc.collectionView.numberOfSections == 3 {
                        vc.collectionView.deleteSections(IndexSet(integer: 2))
                    }
                    viewModel.filteredWeeksOfYear = [Int](repeating: -1, count: 6)
                    vc.collectionView.reloadSections(IndexSet(integer: 1))
                }, completion: { _ in
                    vc.collectionView.scrollToItem(at: IndexPath(item: 0, section: 1), at: .top, animated: true)
                })
            })
            .disposed(by: bag)
        
        output
            .nowLoadingWithBefore
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, mode in
                vc.collectionView.performBatchUpdates {
                    vc.nowLoading = true
                    switch mode {
                    case .notice:
                        if vc.collectionView.numberOfSections == 2 {
                            vc.collectionView.insertSections(IndexSet(integer: 2))
                            vc.collectionView.reloadSections(IndexSet(1..<3))
                        }
                    case .calendar:
                        if vc.collectionView.numberOfSections == 3 {
                            vc.collectionView.deleteSections(IndexSet(integer: 2))
                            vc.collectionView.reloadSections(IndexSet(1..<2))
                        }
                    default: break
                    }
                    
                }
            })
            .disposed(by: bag)
        
        output
            .needReloadMemberAt
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, index in
                vc.collectionView.reloadItems(at: [IndexPath(item: index, section: 2)])
            })
            .disposed(by: bag)
        
        output
            .memberKickedOutAt
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, index in
                vc.collectionView.deleteItems(at: [IndexPath(item: index, section: 2)])
            })
            .disposed(by: bag)
        
        output
            .onlineStateChanged
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, isOnline in
                guard let view = vc.collectionView.supplementaryView(forElementKind: Self.headerElementKind, at: IndexPath(item: 0, section: 0)) as? MyGroupInfoHeaderView else { return }
                view.onlineButton.isOn = isOnline
                view.onlineCountLabel.text = String(viewModel.onlineCount ?? 0)
                
            })
            .disposed(by: bag)
        
        output
            .showDailyPage
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, date in
                guard let groupId = viewModel.groupId,
                      let groupName = viewModel.groupTitle,
                      let isOwner = viewModel.isLeader else { return }
                let nm = NetworkManager()
                let kc = KeyChainManager()
                let tokenRepo = DefaultTokenRepository(apiProvider: nm, keyChainManager: kc)
                let gcr = DefaultGroupCalendarRepository(apiProvider: nm)
                let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
                let refTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
                let fetchGroupDailyTodoListUseCase = DefaultFetchGroupDailyCalendarUseCase(groupCalendarRepository: gcr)
                let fetchMemberDailyCalendarUseCase = DefaultFetchGroupMemberDailyCalendarUseCase(memberCalendarRepository: DefaultGroupMemberCalendarRepository(apiProvider: nm))
                let viewModel = SocialTodoDailyViewModel(
                    getTokenUseCase: getTokenUseCase,
                    refreshTokenUseCase: refTokenUseCase,
                    fetchGroupDailyTodoListUseCase: fetchGroupDailyTodoListUseCase,
                    fetchMemberDailyCalendarUseCase: fetchMemberDailyCalendarUseCase,
                    createGroupTodoUseCase: DefaultCreateGroupTodoUseCase.shared,
                    updateGroupTodoUseCase: DefaultUpdateGroupTodoUseCase.shared,
                    deleteGroupTodoUseCase: DefaultDeleteGroupTodoUseCase.shared,
                    updateGroupCategoryUseCase: DefaultUpdateGroupCategoryUseCase.shared
                )
                viewModel.setGroup(group: GroupName(groupId: groupId, groupName: groupName), type: .group(isLeader: isOwner), date: date)
                let viewController = SocialTodoDailyViewController(viewModel: viewModel)
                
                let nav = UINavigationController(rootViewController: viewController)
                nav.modalPresentationStyle = .pageSheet
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                }
                vc.present(nav, animated: true)
            })
            .disposed(by: bag)
        
        output
            .showMemberProfileAt
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, index in
                guard let groupId = viewModel.groupId,
                      let groupTitle = viewModel.groupTitle,
                      let member = viewModel.memberList?[index] else { return }
                let groupName = GroupName(groupId: groupId, groupName: groupTitle)
                
                let api = NetworkManager()
                let memberCalendarRepo = DefaultGroupMemberCalendarRepository(apiProvider: api)
                let createMonthlyCalendarUseCase = DefaultCreateMonthlyCalendarUseCase()
                let fetchMemberTodoUseCase = DefaultFetchGroupMemberCalendarUseCase(memberCalendarRepository: memberCalendarRepo)
                let dateFormatYYYYMMUseCase = DefaultDateFormatYYYYMMUseCase()
                let keyChainManager = KeyChainManager()
                
                let tokenRepo = DefaultTokenRepository(apiProvider: api, keyChainManager: keyChainManager)
                let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
                let refreshTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
                
                let vm = MemberProfileViewModel(
                    createMonthlyCalendarUseCase: createMonthlyCalendarUseCase,
                    dateFormatYYYYMMUseCase: dateFormatYYYYMMUseCase,
                    getTokenUseCase: getTokenUseCase,
                    refreshTokenUseCase: refreshTokenUseCase,
                    fetchMemberCalendarUseCase: fetchMemberTodoUseCase,
                    fetchImageUseCase: DefaultFetchImageUseCase(imageRepository: DefaultImageRepository.shared)
                )

                vm.setMember(group: groupName, member: member)

                let viewController = MemberProfileViewController(viewModel: vm)
                vc.navigationController?.pushViewController(viewController, animated: true)
            })
            .disposed(by: bag)
    }
    
    func configureView() {
        self.view.backgroundColor = UIColor(hex: 0xF5F5FB)
        self.view.addSubview(collectionView)
        self.view.addSubview(buttonsView)
        buttonList.forEach {
            buttonsView.addButton(button: $0)
        }
        self.view.addSubview(swipeBar)
        
        buttonsView.isHidden = true
//        swipeBar.isHidden = true
        
    }
    
    func configureGestureRecognizer() {
        print("ddd")
        let pgr = UIPanGestureRecognizer(target: self, action: #selector(pan))
        swipeBar.addGestureRecognizer(pgr)
    }
    
    func configureLayout() {
        collectionView.snp.makeConstraints {
            $0.top.leading.trailing.bottom.equalToSuperview()
        }
        
        swipeBar.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.width.equalTo(100)
            $0.height.equalTo(40)
            $0.bottom.equalToSuperview().inset(30)
        }

        buttonsView.snp.makeConstraints {
            $0.centerY.equalTo(swipeBar)
            $0.trailing.equalToSuperview().inset(initialTrailing)
        }
    }
    @objc func swipe(_ gestureRecognizer: UISwipeGestureRecognizer) {
        print("swipe")
        if gestureRecognizer.direction == .left {
            print("swipe")
//            buttonsView.snp.remakeConstraints {
//                $0.bottom.equalToSuperview().inset(50)
//                $0.trailing.equalTo(self.view).inset(targetTrailing)
//            }
//
//            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
//                self.view.layoutIfNeeded()
//            }, completion: { _ in
//                self.buttonList[0].setImage(UIImage(named: "menuHideBtn"), for: .normal)
//                self.buttonsView.stretch()
//            })
        }
    }
    
    @objc func pan(_ gestureRecognizer: UIPanGestureRecognizer) {
        print("in pgr")
        let location = gestureRecognizer.location(in: view)
        print(location)
        switch gestureRecognizer.state {
        case .began:
            firstXOffset = location.x
        case .ended:
            guard let firstXOffset else { return }
            let endXOffset = location.x
            print("moved: \(firstXOffset - endXOffset)")
            if firstXOffset - endXOffset >= 5 {
//                self.buttonList[0].setImage(UIImage(named: "menuHideBtn"), for: .normal)
//                self.buttonsView.alpha = 0
//                self.buttonsView.isHidden = false
//                self.buttonsView.stretch()
//
//                buttonsView.snp.remakeConstraints {
//                    $0.bottom.equalToSuperview().inset(50)
//                    $0.trailing.equalTo(self.view).inset(targetTrailing)
//                }
//
//                swipeBar.snp.remakeConstraints {
//                    $0.leading.equalTo(self.view.snp.trailing)
//                    $0.bottom.equalToSuperview().inset(30)
//                }
//                UIView.animate(withDuration: 0.1, animations: {
//                    self.buttonsView.alpha = 1
//                })
//                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
//                    self.view.layoutIfNeeded()
//                })
            }
            self.firstXOffset = nil
        default:
            break
        }
    }
    
    @objc func buttonTapped(_ sender: UIButton) {
        if sender.tag == 0 {
            buttonsView.shrink { [weak self] in
                self?.buttonsView.snp.remakeConstraints {
                    $0.bottom.equalToSuperview().inset(50)
                    $0.trailing.equalToSuperview().inset(self?.initialTrailing ?? 0)
                }
                self?.swipeBar.snp.remakeConstraints {
                    $0.trailing.equalToSuperview()
                    $0.bottom.equalToSuperview().inset(30)
                }
                UIView.animate(withDuration: 0.1, delay: 0.1, animations: {
                    self?.buttonsView.alpha = 0
                }, completion: { _ in
                    self?.buttonsView.isHidden = true
                })
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                    self?.view.layoutIfNeeded()
                })
            }
        } else {
            didTappedButtonAt.onNext(sender.tag)
        }
    }
    
    @objc func backBtnAction() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func shareBtnAction() {
    }
}

extension MyGroupDetailViewController2: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch viewModel?.mode {
        case .notice:
            if indexPath.section == 2 {
                didSelectedMemberAt.onNext(indexPath.item)
            }
        case .calendar:
            if indexPath.section == 1 {
                didSelectedDayAt.onNext(indexPath.item)
            }
        default: break
        }
        return false
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let mode = viewModel?.mode
        switch mode {
        case .notice:
            return 3
        case .calendar:
            return 2
        case .chat:
            return 2
        default:
            return 0
        }
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if nowLoading {
            return section == 0 ? 0 : 1
        }
        
        switch viewModel?.mode {
        case .notice:
            switch section {
            case 0:
                return 0
            case 1:
                return 1
            case 2:
                return viewModel?.memberList?.count ?? 0 // 똥글뱅이 보여줘야함..!!!
            default:
                return 0
            }
        case .calendar:
            switch section {
            case 0:
                return 0
            case 1:
                return viewModel?.mainDayList.count ?? 0
            default:
                return 0
            }
        case .chat:
            return 0
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if nowLoading {
            switch indexPath.section {
            case 1:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MyGroupDetailLoadingCell.reuseIdentifier, for: indexPath) as? MyGroupDetailLoadingCell else { return UICollectionViewCell() }
                cell.start()
                return cell
            default:
                return UICollectionViewCell()
            }
        }
        
        let mode = viewModel?.mode
        switch mode {
        case .notice:
            switch indexPath.section {
            case 1:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GroupIntroduceNoticeCell.reuseIdentifier, for: indexPath) as? GroupIntroduceNoticeCell,
                      let item = viewModel?.notice else { return UICollectionViewCell() }
                cell.fill(notice: item)
                return cell
            case 2:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: JoinedGroupMemberCell.reuseIdentifier, for: indexPath) as? JoinedGroupMemberCell,
                        let item = viewModel?.memberList?[indexPath.item] else { return UICollectionViewCell() }
                
                cell.fill(name: item.nickname, introduce: item.description, isCaptin: item.isLeader, isOnline: item.isOnline)
                
                if let url = item.profileImageUrl {
                    viewModel?.fetchImage(key: url)
                        .observe(on: MainScheduler.asyncInstance)
                        .subscribe(onSuccess: { data in
                            cell.fill(image: UIImage(data: data))
                        })
                        .disposed(by: bag)
                } else {
                    cell.fill(image: UIImage(named: "DefaultProfileMedium"))
                }
                
                return cell
                
            default:
                return UICollectionViewCell()
            }
        case .calendar:
            switch indexPath.section {
            case 1:
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DailyCalendarCell.identifier, for: indexPath) as? DailyCalendarCell else {
                    return UICollectionViewCell()
                }
                return calendarCell(cell: cell, indexPath: indexPath)
            default:
                return UICollectionViewCell()
            }
        case .chat:
            return UICollectionViewCell()
        default:
            return UICollectionViewCell()
        }
    
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section == 0 {
            guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: Self.headerElementKind, withReuseIdentifier: MyGroupInfoHeaderView.reuseIdentifier, for: indexPath) as? MyGroupInfoHeaderView else { return UICollectionReusableView() }
            var viewBag = DisposeBag()
            view.viewBag = viewBag
            
            view.fill(
                title: viewModel?.groupTitle ?? "",
                tag: viewModel?.tag?.map { "#\($0)" }.joined(separator: " ") ?? "",
                memCount: String(viewModel?.memberCount ?? 0),
                captin: viewModel?.leaderName ?? "",
                onlineCount: String(viewModel?.onlineCount ?? 0),
                isOnline: (try? viewModel?.isOnline.value()) ?? false
            )
            
            if let url = viewModel?.groupImageUrl {
                viewModel?.fetchImage(key: url)
                    .observe(on: MainScheduler.asyncInstance)
                    .subscribe(onSuccess: { data in
                        view.fill(image: UIImage(data: data))
                    })
                    .disposed(by: viewBag)
            }
            
            view.onlineButton
                .rx.tap
                .throttle(.milliseconds(500), latest: false, scheduler: MainScheduler.instance)
                .withUnretained(self)
                .subscribe(onNext: { vc, _ in
                    view.onlineButton.isOn = !view.onlineButton.isOn
                    vc.didTappedOnlineButton.onNext(())
                })
                .disposed(by: viewBag)
            
            return view
        }
        
        let mode = viewModel?.mode
        switch mode {
        case .notice:
            guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: Self.headerElementKind, withReuseIdentifier: GroupIntroduceDefaultHeaderView.reuseIdentifier, for: indexPath) as? GroupIntroduceDefaultHeaderView else { return UICollectionReusableView() }
            switch indexPath.section {
            case 1:
                view.fill(title: "공지 사항", description: "우리 이렇게 진행해요")
            case 2:
                view.fill(title: "그룹 멤버", description: "우리 이렇게 함께해요")
            default:
                break
            }
            return view
        case .calendar:
            guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: JoinedGroupDetailCalendarHeaderView.reuseIdentifier, for: indexPath) as? JoinedGroupDetailCalendarHeaderView else { return UICollectionReusableView() }
            let bag = DisposeBag()
            view.yearMonthButton.setTitle(viewModel?.currentDateText, for: .normal)
            view.yearMonthButton.rx.tap
                .withUnretained(self)
                .subscribe(onNext: { vc, _ in
                    
                    let dateMonth = vc.viewModel?.currentDate ?? Date()
                    let firstMonth = Calendar.current.date(byAdding: DateComponents(month: -100), to: dateMonth) ?? Date()
                    let lastMonth = Calendar.current.date(byAdding: DateComponents(month: 500), to: dateMonth) ?? Date()
                    
                    let viewController = MonthPickerViewController(firstYear: firstMonth, lastYear: lastMonth, currentDate: dateMonth) { date in
                        vc.didChangedMonth.onNext(date)
                    }

                    viewController.preferredContentSize = CGSize(width: 320, height: 290)
                    viewController.modalPresentationStyle = .popover
                    let popover: UIPopoverPresentationController = viewController.popoverPresentationController!
                    popover.delegate = vc
                    popover.sourceView = vc.view
                    
                    let globalFrame = view.yearMonthButton.convert(view.yearMonthButton.bounds, to: vc.view)

                    popover.sourceRect = CGRect(x: globalFrame.midX, y: globalFrame.maxY, width: 0, height: 0)
                    popover.permittedArrowDirections = [.up]
                    vc.present(viewController, animated: true, completion:nil)
                })
                .disposed(by: bag)
            view.bag = bag
            return view
        case .chat:
            return UICollectionReusableView()
        default:
            return UICollectionReusableView()
        }
        
    }
}


extension MyGroupDetailViewController2 {
    func setMenuButton(isLeader: Bool?) {
        let image = UIImage(named: "dotBtn")
        var item: UIBarButtonItem
        var menuChild = [UIAction]()

        if isLeader ?? false {
            let editInfo = UIAction(title: "그룹 정보 수정", image: UIImage(systemName: "pencil"), handler: { [weak self] _ in
                self?.editInfo()
            })
            
            let editNotice = UIAction(title: "공지사항 수정", image: UIImage(systemName: "speaker.badge.exclamationmark.fill"), handler: { [weak self] _ in
                self?.editNotice()
            })
            let editMember = UIAction(title: "멤버 수정", image: UIImage(systemName: "person"), handler: { [weak self] _ in
                self?.editMember()
            })
            
            menuChild.append(editInfo)
            menuChild.append(editNotice)
            menuChild.append(editMember)
        } else {
            let withdraw = UIAction(title: "그룹 탈퇴하기", image: UIImage(systemName: "rectangle.portrait.and.arrow.forward"), attributes: .destructive, handler: { [weak self] _ in
                self?.withdrawGroup()
            })
            
            menuChild.append(withdraw)
        }
        
        let menu = UIMenu(options: .displayInline, children: menuChild)
        item = UIBarButtonItem(image: image, menu: menu)
        item.tintColor = UIColor(hex: 0x000000)
        navigationItem.setRightBarButton(item, animated: true)
    }
    
    func withdrawGroup() {
        self.showPopUp(title: "그룹 탈퇴하기", message: "정말로 그룹을 탈퇴하시겠습니까?", alertAttrs: [
            CustomAlertAttr(title: "취소", actionHandler: {}, type: .normal),
            CustomAlertAttr(title: "탈퇴", actionHandler: { [weak self] in self?.viewModel?.withdrawGroup()}, type: .warning)]
        )
    }
    
    func editNotice() {
        guard let groupId = viewModel?.groupId,
              let notice = viewModel?.notice else { return }
        
        let api = NetworkManager()
        let keyChain = KeyChainManager()
        let tokenRepo = DefaultTokenRepository(apiProvider: api, keyChainManager: keyChain)
        let myGroupRepo = DefaultMyGroupRepository(apiProvider: api)
        let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
        let refreshTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
        let updateNoticeUseCase = DefaultUpdateNoticeUseCase.shared
    
        let vm = MyGroupNoticeEditViewModel(
            getTokenUseCase: getTokenUseCase,
            refreshTokenUseCase: refreshTokenUseCase,
            updateNoticeUseCase: updateNoticeUseCase
        )
        vm.setNotice(groupId: groupId, notice: notice)
        let vc = MyGroupNoticeEditViewController(viewModel: vm)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func editMember() {
        guard let groupId = viewModel?.groupId else { return }
        
        let api = NetworkManager()
        let keyChain = KeyChainManager()
        let tokenRepo = DefaultTokenRepository(apiProvider: api, keyChainManager: keyChain)
        let myGroupRepo = DefaultMyGroupRepository(apiProvider: api)
        let imageRepo = DefaultImageRepository(apiProvider: api)
        let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
        let refreshTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
        let fetchMyGroupMemberListUseCase = DefaultFetchMyGroupMemberListUseCase(myGroupRepository: myGroupRepo)
        let fetchImageUseCase = DefaultFetchImageUseCase(imageRepository: imageRepo)
        
        let vm = MyGroupMemberEditViewModel(
            getTokenUseCase: getTokenUseCase,
            refreshTokenUseCase: refreshTokenUseCase,
            fetchMyGroupMemberListUseCase: fetchMyGroupMemberListUseCase,
            fetchImageUseCase: fetchImageUseCase,
            memberKickOutUseCase: DefaultMemberKickOutUseCase.shared
        )
        vm.setGroupId(id: groupId)
        let vc = MyGroupMemberEditViewController(viewModel: vm)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func editInfo() {
        let api = NetworkManager()
        let keyChain = KeyChainManager()
        let tokenRepo = DefaultTokenRepository(apiProvider: api, keyChainManager: keyChain)
        let myGroupRepo = DefaultMyGroupRepository(apiProvider: api)
        let imageRepo = DefaultImageRepository(apiProvider: api)
        let getTokenUseCase = DefaultGetTokenUseCase(tokenRepository: tokenRepo)
        let refreshTokenUseCase = DefaultRefreshTokenUseCase(tokenRepository: tokenRepo)
        let updateGroupInfoUseCase = DefaultUpdateGroupInfoUseCase.shared
        let vm = MyGroupInfoEditViewModel(
            getTokenUseCase: getTokenUseCase,
            refreshTokenUseCase: refreshTokenUseCase,
            fetchImageUseCase: DefaultFetchImageUseCase(imageRepository: imageRepo),
            updateGroupInfoUseCase: updateGroupInfoUseCase,
            deleteGroupUseCase: DefaultDeleteGroupUseCase.shared
        )
        guard let id = self.viewModel?.groupId,
              let title = self.viewModel?.groupTitle,
              let url = self.viewModel?.groupImageUrl,
              let tagList = self.viewModel?.tag,
              let max = self.viewModel?.limitCount else { return }
        vm.setGroup(id: id, title: title, imageUrl: url, tagList: tagList, maxMember: max)
        
        let vc = MyGroupInfoEditViewController(viewModel: vm)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension MyGroupDetailViewController2 {
    private func createInfoSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(1), heightDimension: .absolute(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(1),heightDimension: .absolute(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)
        
        let sectionHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                       heightDimension: .absolute(330))

        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: sectionHeaderSize,
            elementKind: Self.headerElementKind,
            alignment: .top
        )

        section.boundarySupplementaryItems = [sectionHeader]
                
        return section
    }
    
    private func createNoticeSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(200))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 30, trailing: 0)
        let sectionHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                       heightDimension: .absolute(70))
        
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: sectionHeaderSize,
            elementKind: Self.headerElementKind,
            alignment: .top
        )

        section.boundarySupplementaryItems = [sectionHeader]

        return section
    }
    
    private func createMemberSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(66))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        group.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 26, bottom: 0, trailing: 26)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 85, trailing: 0)
        let sectionHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                       heightDimension: .absolute(70))
        
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: sectionHeaderSize,
            elementKind: Self.headerElementKind,
            alignment: .top
        )
        
        section.boundarySupplementaryItems = [sectionHeader]

        return section
    }
    
    private func createCalendarSection() -> NSCollectionLayoutSection {
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(Double(1)/Double(7)),
            heightDimension: .estimated(110)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(110)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
                
        let sectionHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                       heightDimension: .absolute(80))
        
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: sectionHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )

        section.boundarySupplementaryItems = [sectionHeader]
        
        return section
    }
    
    private func createLoadSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        return section
    }
    
    private func createLayout() -> UICollectionViewLayout {
        return StickyTopCompositionalLayout { [weak self] (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self,
                  let mode = self.viewModel?.mode else { return nil }
            
            if sectionIndex == 0 {
                return self.createInfoSection()
            }
            
            if self.nowLoading {
                return self.createLoadSection()
            }

            switch mode {
            case .notice:
                switch sectionIndex {
                case 1:
                    return self.createNoticeSection()
                case 2:
                    return self.createMemberSection()
                default:
                    return nil
                }
            case .calendar:
                return self.createCalendarSection()
            case .chat:
                return nil
            default:
                return nil
            }
        }
    }
}

extension MyGroupDetailViewController2: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension MyGroupDetailViewController2 {
    func calendarCell(cell: DailyCalendarCell, indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel else { return UICollectionViewCell() }
        let screenWidth = UIScreen.main.bounds.width
        
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        
        let currentDate = viewModel.mainDayList[indexPath.item].date
        if viewModel.filteredWeeksOfYear[indexPath.item/7] != calendar.component(.weekOfYear, from: currentDate) {
            viewModel.filteredWeeksOfYear[indexPath.item/7] = calendar.component(.weekOfYear, from: currentDate)
            (indexPath.item - indexPath.item%7..<indexPath.item - indexPath.item%7 + 7).forEach {
                viewModel.blockMemo[$0] = [Int?](repeating: nil, count: 20)
            }
            for (item, dayViewModel) in Array(viewModel.mainDayList.enumerated())[indexPath.item - indexPath.item%7..<indexPath.item - indexPath.item%7 + 7] {
                var filteredTodoList = viewModel.todos[dayViewModel.date] ?? []
                
                var periodList = filteredTodoList.filter { $0.startDate != $0.endDate }
                let singleList = filteredTodoList.filter { $0.startDate == $0.endDate }
                
                if item % 7 != 0 { // 만약 월요일이 아닐 경우, 오늘 시작하는것들만, 월요일이면 포함되는 전체 다!
                    periodList = periodList.filter { $0.startDate == dayViewModel.date }
                        .sorted { $0.endDate < $1.endDate }
                } else { //월요일 중에 오늘이 startDate가 아닌 놈들만 startDate로 정렬, 그 뒤에는 전부다 endDate로 정렬하고, 이걸 다시 endDate를 업댓해줘야함!
                    
                    var continuousPeriodList = periodList
                        .filter { $0.startDate != dayViewModel.date }
                        .sorted{ ($0.startDate == $1.startDate) ? $0.endDate < $1.endDate : $0.startDate < $1.startDate }
                        .map { todo in
                            var tmpTodo = todo
                            tmpTodo.startDate = dayViewModel.date
                            return tmpTodo
                        }
                    
                    var initialPeriodList = periodList
                        .filter { $0.startDate == dayViewModel.date } //이걸 바로 end로 정렬해도 되나? -> 애를 바로 end로 정렬할 경우?
                        .sorted{ $0.endDate < $1.endDate }
                    
                    periodList = continuousPeriodList + initialPeriodList
                }
                
                periodList = periodList.map { todo in
                    let currentWeek = calendar.component(.weekOfYear, from: dayViewModel.date)
                    let endWeek = calendar.component(.weekOfYear, from: todo.endDate)
                    
                    if currentWeek != endWeek {
                        let firstDayOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: dayViewModel.date))
                        let lastDayOfWeek = calendar.date(byAdding: .day, value: 6, to: firstDayOfWeek!) //이게 이번주 일요일임.
                        var tmpTodo = todo
                        tmpTodo.endDate = lastDayOfWeek!
                        return tmpTodo
                    } else { return todo }
                }
                
                let periodTodo: [(Int, SocialTodoSummary)] = periodList.compactMap { todo in
                    for i in (0..<viewModel.blockMemo[item].count) {
                        if viewModel.blockMemo[item][i] == nil,
                           let period = Calendar.current.dateComponents([.day], from: todo.startDate, to: todo.endDate).day {
                            for j in (0...period) {
                                viewModel.blockMemo[item+j][i] = todo.todoId
                            }
                            return (i, todo)
                        }
                    }
                    return nil
                }
                
                var singleStartIndex = 0
                viewModel.blockMemo[item].enumerated().forEach { (index, tuple) in
                    if tuple != nil {
                        singleStartIndex = index + 1
                    }
                }
                
                let singleTodo = singleList.enumerated().map { (index, todo) in
                    return (index + singleStartIndex, todo)
                }
                
                var holidayMock: (Int, String)?
                if let holidayTitle = HolidayPool.shared.holidays[dayViewModel.date] {
                    let holidayIndex = singleStartIndex + singleTodo.count
                    holidayMock = (holidayIndex, holidayTitle)
                }
                
                viewModel.filteredTodoCache[item] = FilteredSocialTodoViewModel(periodTodo: periodTodo, singleTodo: singleTodo, holiday: holidayMock)
            }
        }
        
        let weekRange = (indexPath.item - indexPath.item%7..<indexPath.item - indexPath.item%7 + 7)
        
        guard let maxItem = viewModel.filteredTodoCache[weekRange]
            .max(by: { a, b in
                let aHeight = (a.holiday != nil) ? a.holiday!.0 : (a.singleTodo.last != nil) ?
                a.singleTodo.last!.0 : (a.periodTodo.last != nil) ? a.periodTodo.last!.0 : 0
                let bHeight = (b.holiday != nil) ? b.holiday!.0 : (b.singleTodo.last != nil) ?
                b.singleTodo.last!.0 : (b.periodTodo.last != nil) ? b.periodTodo.last!.0 : 0
                return aHeight < bHeight
            }) else { return UICollectionViewCell() }
                
        guard var todosHeight = (maxItem.holiday != nil) ?
                maxItem.holiday?.0 : (maxItem.singleTodo.count != 0) ?
                maxItem.singleTodo.last?.0 : (maxItem.periodTodo.count != 0) ?
                maxItem.periodTodo.last?.0 : 0 else { return UICollectionViewCell() }
        
        var height: CGFloat
        if let cellHeight = viewModel.cachedCellHeightForTodoCount[todosHeight] {
            height = cellHeight
        } else {
            let mockCell = DailyCalendarCell(mockFrame: CGRect(x: 0, y: 0, width: Double(1)/Double(7) * UIScreen.main.bounds.width, height: 110))
            mockCell.socialFill(
                periodTodoList: maxItem.periodTodo,
                singleTodoList: maxItem.singleTodo,
                holiday: maxItem.holiday
            )
            
            mockCell.layoutIfNeeded()
            
            let estimatedSize = mockCell.systemLayoutSizeFitting(CGSize(
                width: Double(1)/Double(7) * UIScreen.main.bounds.width,
                height: UIView.layoutFittingCompressedSize.height
            ))
            let estimatedHeight = estimatedSize.height + mockCell.stackView.topY + 3
            let targetHeight = (estimatedHeight > 110) ? estimatedHeight : 110
            height = targetHeight
        }
        
        let dayViewModel = viewModel.mainDayList[indexPath.item]
        let filteredTodo = viewModel.filteredTodoCache[indexPath.item]
        
        cell.fill(
            day: "\(Calendar.current.component(.day, from: dayViewModel.date))",
            state: dayViewModel.state,
            weekDay: WeekDay(rawValue: (Calendar.current.component(.weekday, from: dayViewModel.date)+5)%7)!,
            isToday: dayViewModel.date == viewModel.today,
            isHoliday: HolidayPool.shared.holidays[dayViewModel.date] != nil,
            height: height
        )
        
        cell.socialFill(periodTodoList: filteredTodo.periodTodo, singleTodoList: filteredTodo.singleTodo, holiday: filteredTodo.holiday)
        return cell
    }
}
