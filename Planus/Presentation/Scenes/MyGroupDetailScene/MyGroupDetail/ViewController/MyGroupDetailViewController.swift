//
//  MyGroupDetailViewController2.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/22.
//

import UIKit
import RxSwift
import RxCocoa

final class MyGroupDetailViewController: UIViewController, UIGestureRecognizerDelegate {
    var bag = DisposeBag()
    
    let headerHeight: CGFloat = 330
    
    let didChangedMonth = PublishRelay<Date>()
    var didSelectedDayAt = PublishRelay<Int>()
    var didSelectedMemberAt = PublishRelay<Int>()
    var didTappedOnlineButton = PublishRelay<Void>()
    
    var didTappedShareBtn = PublishRelay<Void>()
    var didTappedInfoEditBtn = PublishRelay<Void>()
    var didTappedMemberEditBtn = PublishRelay<Void>()
    var didTappedNoticeEditBtn = PublishRelay<Void>()
    
    var didTappedYearMonthBtn = PublishRelay<Void>()
    
    var nowLoading: Bool = false
    
    var didTappedButtonAt = PublishSubject<Int>()
    var modeChanged: Bool = false
        
    lazy var buttonList: [UIButton] = {
        return MyGroupDetailNavigatorType.allCases.map { [weak self] in
            let image = UIImage(named: $0.imageTitle) ?? UIImage()
            let button = SpringableButton(frame: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            button.setImage(image, for: .normal)
            button.tag = $0.rawValue
            button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
            return button
        }
    }()
    
    let dimmedView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        return view
    }()
    
    let  swipeBar: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "swipeBarLeft"))
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    let  buttonsView: AnimatedStrechButtonListView = {
        let stretchButtonView = AnimatedStrechButtonListView(axis: .up)
        return stretchButtonView
    }()
    
    var viewModel: MyGroupDetailViewModel?
    
    lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        
        cv.register(GroupIntroduceNoticeCell.self,
                    forCellWithReuseIdentifier: GroupIntroduceNoticeCell.reuseIdentifier)
        
        cv.register(MyGroupMemberCell.self,
                    forCellWithReuseIdentifier: MyGroupMemberCell.reuseIdentifier)
        
        cv.register(GroupIntroduceDefaultHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: GroupIntroduceDefaultHeaderView.reuseIdentifier)
        
        cv.register(MyGroupInfoHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: MyGroupInfoHeaderView.reuseIdentifier)
        
        cv.register(CalendarDailyCell.self, forCellWithReuseIdentifier: CalendarDailyCell.identifier)
        cv.register(MyGroupDetailCalendarHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyGroupDetailCalendarHeaderView.reuseIdentifier)
        
        
        cv.dataSource = self
        cv.delegate = self
        cv.backgroundColor = .planusBackgroundColor
        return cv
    }()
    
    let backButton: UIBarButtonItem = {
        let image = UIImage(named: "back")
        let item = UIBarButtonItem(image: image, style: .plain, target: nil, action: nil)
        item.tintColor = .planusBlack
        return item
    }()
    
    convenience init(viewModel: MyGroupDetailViewModel) {
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
        scrollingAppearance.backgroundColor = .planusBackgroundColor
        let initialBarButtonAppearance = UIBarButtonItemAppearance()
        initialBarButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.planusWhite]
        initialAppearance.configureWithTransparentBackground()
        initialAppearance.buttonAppearance = initialBarButtonAppearance
        
        let scrollingBarButtonAppearance = UIBarButtonItemAppearance()
        scrollingBarButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.planusBlack]
        scrollingAppearance.buttonAppearance = scrollingBarButtonAppearance
        self.navigationItem.standardAppearance = scrollingAppearance
        self.navigationItem.scrollEdgeAppearance = initialAppearance
        
        self.navigationController?.navigationBar.standardAppearance = scrollingAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = initialAppearance
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            viewModel?.actions.finishScene?()
        }
    }
}

// MARK: - bind
extension MyGroupDetailViewController {
    func bind() {
        guard let viewModel else { return }
        
        didTappedYearMonthBtn
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                guard let view = vc.collectionView.supplementaryView(
                    forElementKind: UICollectionView.elementKindSectionHeader,
                    at: IndexPath(item: 0, section: MyGroupDetailPageAttribute.calendar.sectionIndex)
                ) as? MyGroupDetailCalendarHeaderView else { return }
                vc.showMonthPickerVC(sourceView: view.yearMonthButton)
            })
            .disposed(by: bag)
        
        let input = MyGroupDetailViewModel.Input(
            viewDidLoad: Observable.just(()),
            didTappedModeBtnAt: didTappedButtonAt.asObservable(),
            didChangedMonth: didChangedMonth.asObservable(),
            didSelectedDayAt: didSelectedDayAt.asObservable(),
            didSelectedMemberAt: didSelectedMemberAt.asObservable(),
            didTappedOnlineButton: didTappedOnlineButton.asObservable(),
            didTappedShareBtn: didTappedShareBtn.asObservable(),
            didTappedInfoEditBtn: didTappedInfoEditBtn.asObservable(),
            didTappedMemberEditBtn: didTappedMemberEditBtn.asObservable(),
            didTappedNoticeEditBtn: didTappedNoticeEditBtn.asObservable(),
            backBtnTapped: backButton.rx.tap.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        output
            .showMessage
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, message in
                vc.showToast(message: message)
            })
            .disposed(by: bag)
        
        output
            .didInitialFetch
            .take(1)
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                vc.nowLoading = false
                
                vc.setMenuButton(isLeader: viewModel.isLeader)
                
                guard let mode = viewModel.mode else { return }
                vc.setSectionCount(mode: mode, trailingAction: {
                    vc.collectionView.reloadSections(IndexSet(mode.attributes.map { $0.sectionIndex }))
                }, completion: {
                    vc.swipeBar.setAnimatedIsHidden(false, duration: 0.2)
                })
            })
            .disposed(by: self.bag)
        
        output
            .modeChanged
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                vc.modeChanged = true
            })
            .disposed(by: bag)
        
        output
            .didFetchInfo
            .compactMap { $0 }
            .skip(1)
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
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
                guard let mode = viewModel.mode else { return }
                vc.nowLoading = false
                vc.setSectionCount(mode: mode, trailingAction: {
                    vc.collectionView.reloadSections(IndexSet(integer: MyGroupDetailPageAttribute.notice.sectionIndex))
                }, completion: {
                    if vc.modeChanged {
                        vc.modeChanged = false
                        vc.scrollToHeader(section: MyGroupDetailPageAttribute.notice.sectionIndex)
                    }
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
                guard let mode = viewModel.mode else { return }
                vc.nowLoading = false
                vc.setSectionCount(mode: mode, trailingAction: {
                    vc.collectionView.reloadSections(IndexSet(integer: MyGroupDetailPageAttribute.member.sectionIndex))
                }, completion: {
                    if vc.modeChanged {
                        vc.modeChanged = false
                        vc.scrollToHeader(section: MyGroupDetailPageAttribute.notice.sectionIndex)
                    }
                })
            })
            .disposed(by: bag)
        
        output
            .didFetchCalendar
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                guard let mode = viewModel.mode else { return }
                vc.nowLoading = false
                vc.setSectionCount(mode: mode, trailingAction: {
                    vc.collectionView.reloadSections(IndexSet(integer: MyGroupDetailPageAttribute.calendar.sectionIndex))
                }, completion: {
                    if vc.modeChanged {
                        vc.modeChanged = false
                        vc.scrollToHeader(section: MyGroupDetailPageAttribute.calendar.sectionIndex)
                    }
                })
            })
            .disposed(by: bag)
        
        output
            .nowLoadingWithBefore
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, mode in
                vc.nowLoading = true
                vc.setSectionCount(mode: mode, trailingAction: {
                    let indexSet = IndexSet(mode.attributes.filter { $0 != .info }.map { $0.sectionIndex })
                    vc.collectionView.reloadSections(indexSet)
                })
            })
            .disposed(by: bag)
        
        output
            .nowInitLoading
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                vc.nowLoading = true
                guard let mode = viewModel.mode else { return }
                vc.setSectionCount(mode: mode, trailingAction: {
                    let indexSet = IndexSet(mode.attributes.map { $0.sectionIndex })
                    vc.collectionView.reloadSections(indexSet)
                })
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
                guard let view = vc.collectionView.supplementaryView(
                    forElementKind: UICollectionView.elementKindSectionHeader,
                    at: IndexPath(item: 0, section: 0)
                ) as? MyGroupInfoHeaderView else { return }
                
                view.onlineStatusChanged(count: String(viewModel.onlineCount ?? Int()), isOn: isOnline)
            })
            .disposed(by: bag)
        
        output
            .showShareMenu
            .compactMap { $0 }
            .withUnretained(self)
            .subscribe(onNext: { vc, url in
                vc.showShareActivityVC(with: url)
            })
            .disposed(by: bag)
        
    }
}

// MARK: - Actions
extension MyGroupDetailViewController {
    func scrollToHeader(section: Int) {
        guard let layoutAttributes =  collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: section)) else { return }
        let viewOrigin = CGPoint(x: layoutAttributes.frame.origin.x, y: layoutAttributes.frame.origin.y);
        var offset = collectionView.contentOffset;
        let height = (view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0) + (navigationController?.navigationBar.frame.height ?? 0)
        offset.y = viewOrigin.y - collectionView.contentInset.top - height
        collectionView.setContentOffset(offset, animated: true)
    }
    
    func setSectionCount(mode: MyGroupDetailPageType, trailingAction: (() -> Void)? = nil, completion: (() -> Void)? = nil) {
        let newSectionCount = mode.attributes.count
        let currentSectionCount = collectionView.numberOfSections

        collectionView.performBatchUpdates({
            if newSectionCount < currentSectionCount {
                collectionView.deleteSections(IndexSet(newSectionCount..<currentSectionCount))
            } else if newSectionCount > currentSectionCount {
                collectionView.insertSections(IndexSet(currentSectionCount..<newSectionCount))
            }
            trailingAction?()
        }, completion: { _ in completion?() })
    }
}

// MARK: - showVC
extension MyGroupDetailViewController {
    func showShareActivityVC(with url: String) {
        var objectsToShare = [String]()
        objectsToShare.append(url)
        let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact, .markupAsPDF, .openInIBooks, .saveToCameraRoll]
        DispatchQueue.main.async { [weak self] in
            self?.present(activityVC, animated: true)
        }
    }
    
    func showMonthPickerVC(sourceView: UIView) {
        let dateMonth = viewModel?.currentDate ?? Date()
        let firstMonth = Calendar.current.date(byAdding: DateComponents(month: -100), to: dateMonth) ?? Date()
        let lastMonth = Calendar.current.date(byAdding: DateComponents(month: 500), to: dateMonth) ?? Date()
        
        let viewController = MonthPickerViewController(firstYear: firstMonth, lastYear: lastMonth, currentDate: dateMonth) { [weak self] date in
            self?.didChangedMonth.accept(date)
        }

        viewController.preferredContentSize = CGSize(width: 320, height: 290)
        viewController.modalPresentationStyle = .popover
        let popover: UIPopoverPresentationController = viewController.popoverPresentationController!
        popover.delegate = self
        popover.sourceView = self.view
        
        let globalFrame = sourceView.convert(sourceView.bounds, to: self.view)

        popover.sourceRect = CGRect(x: globalFrame.midX, y: globalFrame.maxY, width: 0, height: 0)
        popover.permittedArrowDirections = [.up]
        self.present(viewController, animated: true, completion:nil)
    }
}

// MARK: - Gestures
private extension MyGroupDetailViewController {
    func configureGestureRecognizer() {
        let sgr = UISwipeGestureRecognizer(target: self, action: #selector(swiped))
        sgr.direction = .left
        swipeBar.addGestureRecognizer(sgr)
        
        let lgr = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        lgr.minimumPressDuration = 0
        dimmedView.addGestureRecognizer(lgr)
    }
    
    @objc 
    func longPressed(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            hideModeSelection()
        }
    }
    
    @objc 
    func swiped(_ gestureRecognizer: UISwipeGestureRecognizer) {
        if gestureRecognizer.direction == .left {
            showModeSelection()
        }
    }
    
    @objc 
    func buttonTapped(_ sender: UIButton) {
        if sender.tag == 0 {
            hideModeSelection()
        } else {
            didTappedButtonAt.onNext(sender.tag)
        }
    }
}

// MARK: configure VC
private extension MyGroupDetailViewController {
    func configureView() {
        self.view.backgroundColor = .planusBackgroundColor
        self.view.addSubview(collectionView)
        self.view.addSubview(dimmedView)
        self.view.addSubview(buttonsView)
        
        buttonList.forEach { buttonsView.addButton(button: $0) }
        
        self.view.addSubview(swipeBar)
        
        buttonsView.isHidden = true
        swipeBar.isHidden = true
        dimmedView.isHidden = true
    }
    
    func configureLayout() {
        collectionView.snp.makeConstraints {
            $0.top.leading.trailing.bottom.equalToSuperview()
        }
        
        swipeBar.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(30)
        }

        buttonsView.snp.makeConstraints {
            $0.centerY.equalTo(swipeBar)
            $0.trailing.equalToSuperview().inset(-27)
        }
        
        dimmedView.snp.makeConstraints {
            $0.edges.equalTo(self.view.safeAreaLayoutGuide)
        }
    }
}

// MARK: - mode selection
private extension MyGroupDetailViewController {
    func showModeSelection() {
        self.dimmedView.isHidden = false
        
        self.buttonsView.alpha = 0
        self.buttonsView.isHidden = false
        self.buttonsView.stretch()
        
        buttonsView.snp.remakeConstraints {
            $0.bottom.equalToSuperview().inset(50)
            $0.trailing.equalTo(self.view).inset(20)
        }
        
        swipeBar.snp.remakeConstraints {
            $0.leading.equalTo(self.view.snp.trailing)
            $0.bottom.equalToSuperview().inset(30)
        }
        UIView.animate(withDuration: 0.1, animations: {
            self.buttonsView.alpha = 1
        })
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    func hideModeSelection() {
        self.dimmedView.isHidden = true
        
        buttonsView.shrink { [weak self] in
            self?.buttonsView.snp.remakeConstraints {
                $0.bottom.equalToSuperview().inset(50)
                $0.trailing.equalToSuperview().inset(-27)
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
    }
}

extension MyGroupDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let mode = viewModel?.mode else { return false }
        
        switch mode {
        case .notice:
            if indexPath.section == MyGroupDetailPageAttribute.member.sectionIndex {
                didSelectedMemberAt.accept(indexPath.item)
            }
        case .calendar:
            if indexPath.section == MyGroupDetailPageAttribute.calendar.sectionIndex {
                didSelectedDayAt.accept(indexPath.item)
            }
        }

        return false
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        viewModel?.mode?.attributes.count ?? 0
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let mode = viewModel?.mode else { return 0 }
        
        switch mode.attributes[section] {
        case .info: return 0
        case .notice: return nowLoading ? 1 : (viewModel?.notice != nil) ? 1 : 0
        case .member: return nowLoading ? 6 : (viewModel?.memberList?.count ?? 0)
        case .calendar: return nowLoading ? 42 : (viewModel?.mainDays.count ?? 0)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel,
              let mode = viewModel.mode else { return UICollectionViewCell() }
        
        switch mode.attributes[indexPath.section] {
        case .info: return UICollectionViewCell()
        case .notice:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GroupIntroduceNoticeCell.reuseIdentifier, for: indexPath) as? GroupIntroduceNoticeCell else { return UICollectionViewCell() }
            if nowLoading {
                cell.startSkeletonAnimation()
                return cell
            }
            
            guard let item = viewModel.notice else { return UICollectionViewCell() }
            cell.stopSkeletonAnimation()
            cell.fill(notice: item)
            return cell
        case .member:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MyGroupMemberCell.reuseIdentifier, for: indexPath) as? MyGroupMemberCell else { return UICollectionViewCell() }
            if nowLoading {
                cell.startSkeletonAnimation()
                return cell
            }
            cell.stopSkeletonAnimation()
            
            guard let item = viewModel.memberList?[indexPath.item] else { return UICollectionViewCell() }
            cell.fill(name: item.nickname, introduce: item.description, isCaptin: item.isLeader, isOnline: item.isOnline, imgFetcher: viewModel.fetchImage(key: item.profileImageUrl ?? String()))

            return cell
        case .calendar:
            return calendarCell(collectionView, cellForItemAt: indexPath)
        }
    }
    
    func calendarCell(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel,
              let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDailyCell.identifier, for: indexPath) as? CalendarDailyCell else {
            return UICollectionViewCell()
        }
        
        if nowLoading {
            cell.startSkeletonAnimation()
            return cell
        }
        cell.stopSkeletonAnimation()

        let day = viewModel.mainDays[indexPath.item]

        cell.fill(
            day: "\(Calendar.current.component(.day, from: day.date))",
            state: day.state,
            weekDay: WeekDay(rawValue: (Calendar.current.component(.weekday, from: day.date)+5)%7)!,
            isToday: day.date == viewModel.today,
            isHoliday: HolidayPool.shared.holidays[day.date] != nil
        )
        
        let (maxCount, maxTodo) = viewModel.maxCountDailyViewModelOfWeek(at: IndexPath(item: indexPath.item, section: 0))
        
        let item = viewModel.dailyViewModels[day.date]
        if let cellHeight = viewModel.cachedCellHeightForTodoCount[maxCount] {
            cell.stretch(height: cellHeight)
        } else {
            var targetHeight: CGFloat = 100
            if let maxTodo {
                let mockCell = CalendarDailyCell(mockableFrame: CGRect(x: 0, y: 0, width: Double(1)/Double(7) * UIScreen.main.bounds.width, height: UIView.layoutFittingCompressedSize.height))
                let estimatedHeight = mockCell.fillAndFit(
                    periodTodoList: maxTodo.periodTodo,
                    singleTodoList: maxTodo.singleTodo,
                    holiday: maxTodo.holiday
                )
                targetHeight = max(estimatedHeight, targetHeight)
            }
            viewModel.cachedCellHeightForTodoCount[maxCount] = targetHeight
            cell.stretch(height: targetHeight)
        }
        
        if let item = viewModel.dailyViewModels[day.date] {
            cell.fill(periodTodoList: item.periodTodo, singleTodoList: item.singleTodo, holiday: item.holiday)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        guard let viewModel,
              let mode = viewModel.mode else { return UICollectionViewCell() }
        
        switch mode.attributes[indexPath.section] {
        case .info:
            guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyGroupInfoHeaderView.reuseIdentifier, for: indexPath) as? MyGroupInfoHeaderView else { return UICollectionReusableView() }
            if nowLoading {
                view.startSkeletonAnimation()
                return view
            }
            
            view.stopSkeletonAnimation()
            
            view.fill(
                title: viewModel.groupTitle ?? "",
                tag: viewModel.tag?.map { "#\($0)" }.joined(separator: " ") ?? "",
                memCount: String(viewModel.memberCount ?? 0),
                captin: viewModel.leaderName ?? "",
                onlineCount: String(viewModel.onlineCount ?? 0),
                isOnline: (try? viewModel.isOnline.value()) ?? false,
                imgFetcher: viewModel.fetchImage(key: viewModel.groupImageUrl ?? String()),
                onlineBtnTapped: self.didTappedOnlineButton
            )

            return view
        case .notice, .member:
            guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: GroupIntroduceDefaultHeaderView.reuseIdentifier, for: indexPath) as? GroupIntroduceDefaultHeaderView else { return UICollectionReusableView() }
            if nowLoading {
                view.startSkeletonAnimation()
                return view
            }
            view.stopSkeletonAnimation()
            view.fill(title: mode.attributes[indexPath.section].headerTitle, description: mode.attributes[indexPath.section].headerMessage)
            return view
        case .calendar:
            guard let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyGroupDetailCalendarHeaderView.reuseIdentifier, for: indexPath) as? MyGroupDetailCalendarHeaderView else { return UICollectionReusableView() }
            
            if nowLoading {
                view.startSkeletonAnimation()
                return view
            }
            
            view.stopSkeletonAnimation()
            view.fill(title: viewModel.dateTitle ?? String(), btnTapped: didTappedYearMonthBtn)
            
            return view
        }
    }
}

private extension MyGroupDetailViewController {
    func setMenuButton(isLeader: Bool?) {
        let image = UIImage(named: "dotBtn")
        var item: UIBarButtonItem
        var menuChild = [UIAction]()
        
        let share = UIAction(title: "공유하기", image: UIImage(systemName: "square.and.arrow.up"), handler: { [weak self] _ in
            self?.didTappedShareBtn.accept(())
        })
        menuChild.append(share)

        if isLeader ?? false {
            [
                UIAction(
                    title: "그룹 정보 수정",
                    image: UIImage(systemName: "pencil"),
                    handler: { [weak self] _ in
                        self?.didTappedInfoEditBtn.accept(())
                    }
                ),
                UIAction(
                    title: "공지사항 수정",
                    image: UIImage(systemName: "speaker.badge.exclamationmark.fill"),
                    handler: { [weak self] _ in
                        self?.didTappedNoticeEditBtn.accept(())
                    }
                ),
                UIAction(
                    title: "멤버 수정",
                    image: UIImage(systemName: "person"),
                    handler: { [weak self] _ in
                        self?.didTappedMemberEditBtn.accept(())
                    }
                )
            ]
                .forEach {
                    menuChild.append($0)
                }
        } else {
            let withdraw = UIAction(
                title: "그룹 탈퇴하기",
                image: UIImage(systemName: "rectangle.portrait.and.arrow.forward"),
                attributes: .destructive,
                handler: { [weak self] _ in
                    self?.withdrawGroup()
                })
            
            menuChild.append(withdraw)
        }
        
        let menu = UIMenu(options: .displayInline, children: menuChild)
        item = UIBarButtonItem(image: image, menu: menu)
        item.tintColor = .planusBlack
        navigationItem.setRightBarButton(item, animated: true)
    }
    
    func withdrawGroup() {
        self.showPopUp(title: "그룹 탈퇴하기", message: "정말로 그룹을 탈퇴하시겠습니까?", alertAttrs: [
            CustomAlertAttr(title: "취소", actionHandler: {}, type: .normal),
            CustomAlertAttr(title: "탈퇴", actionHandler: { [weak self] in self?.viewModel?.withdrawGroup()}, type: .warning)]
        )
    }
}

private extension MyGroupDetailViewController {
    func createInfoSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(1), heightDimension: .absolute(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(1),heightDimension: .absolute(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)
        
        let sectionHeaderSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                       heightDimension: .absolute(headerHeight))

        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: sectionHeaderSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )

        section.boundarySupplementaryItems = [sectionHeader]
                
        return section
    }
    
    func createNoticeSection() -> NSCollectionLayoutSection {
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
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )

        section.boundarySupplementaryItems = [sectionHeader]

        return section
    }
    
    func createMemberSection() -> NSCollectionLayoutSection {
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
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        
        section.boundarySupplementaryItems = [sectionHeader]

        return section
    }
    
    func createCalendarSection() -> NSCollectionLayoutSection {
        
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
    
    func createLoadSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        return section
    }
    
    func createLayout() -> UICollectionViewLayout {
        return StickyTopCompositionalLayout(headerHeight: headerHeight) { [weak self] (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self,
                  let mode = self.viewModel?.mode else { return nil }

            switch mode.attributes[sectionIndex] {
            case .info:
                return self.createInfoSection()
            case .notice:
                return self.createNoticeSection()
            case .member:
                return self.createMemberSection()
            case .calendar:
                return self.createCalendarSection()
            }
        }
    }
}

extension MyGroupDetailViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

extension MyGroupDetailNavigatorType {
    var imageTitle: String {
        switch self {
        case .dot:
            return "menuHideBtn"
        case .notice:
            return "NoticeCircleBtn"
        case .calendar:
            return "CalendarCircleBtn"
        }
    }
}
