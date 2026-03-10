//
//  HomeCalendarViewController.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/25.
//

import UIKit
import RxSwift
import RxCocoa

final class HomeCalendarViewController: UIViewController {
    private let bag = DisposeBag()
    private let viewModel: HomeCalendarViewModel
    private var homeCalendarView: HomeCalendarView {
        guard let typedView = view as? HomeCalendarView else {
            fatalError("HomeCalendarViewController.view must be HomeCalendarView")
        }
        return typedView
    }
    
    // MARK: - UI Event
    private let isMonthChanged = PublishRelay<Date>()
    private let nowMultipleSelecting = PublishRelay<Bool>()
    private let multipleItemSelected = PublishRelay<(IndexPath, IndexPath)>()
    private let itemSelected = PublishRelay<IndexPath>()
    private let isGroupSelectedWithId = PublishRelay<Int?>()
    private let refreshRequired = PublishRelay<Void>()
    private let didFetchRefreshedData = PublishRelay<Void>()
    private let movedToIndex = PublishRelay<HomeCalendarViewModel.CalendarMovable>()
    
    private var observeScroll = false

    init(viewModel: HomeCalendarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = HomeCalendarView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()
        configureNavigationBar()
        bind()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()
    }
}

// MARK: - Configure
private extension HomeCalendarViewController {
    func configureCollectionView() {
        homeCalendarView.collectionView.delegate = self
        homeCalendarView.collectionView.dataSource = self
    }

    func configureNavigationBar() {
        navigationItem.titleView = homeCalendarView.yearMonthButton
        navigationItem.setRightBarButton(UIBarButtonItem(customView: homeCalendarView.profileButton), animated: false)
    }
}

// MARK: - Bind
private extension HomeCalendarViewController {
    func bind() {
        let createPeriodTodoCompletionHandler = { indexPath in
            guard let cell = homeCalendarView.collectionView.cellForItem(
                at: indexPath
            ) as? MonthlyCalendarCell else { return }
            cell.deselectItems()
        }
        
        nowMultipleSelecting
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { bool in
                homeCalendarView.collectionView.isScrollEnabled = !bool
                homeCalendarView.collectionView.isUserInteractionEnabled = !bool
            })
            .disposed(by: bag)
        
        let input = HomeCalendarViewModel.Input(
            viewDidLoaded: Observable.just(()),
            movedToIndex: movedToIndex.asObservable(),
            itemSelectedAt: itemSelected.asObservable(),
            multipleItemSelectedInRange: multipleItemSelected.asObservable(),
            titleBtnTapped: homeCalendarView.yearMonthButton.rx.tap.asObservable(),
            monthSelected: isMonthChanged.asObservable(),
            filterGroupWithId: isGroupSelectedWithId.asObservable(),
            refreshRequired: refreshRequired.asObservable(),
            profileBtnTapped: homeCalendarView.profileButton.rx.tap.asObservable(),
            createPeriodTodoCompletionHandler: createPeriodTodoCompletionHandler
        )
        
        let output = viewModel.transform(input: input)

        bind(output: output)
    }

    func bind(output: HomeCalendarViewModel.Output) {
        output.dateTitleUpdated
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] text in
                self?.homeCalendarView.yearMonthButton.setTitle(text, for: .normal)
            })
            .disposed(by: bag)

        output.needMoveTo
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] type in
                guard let self else { return }
                switch type {
                case .initialized(let index):
                    initializeToIndex(centerIndex: index)
                case .jump(let index):
                    jumpToIndex(index: index)
                default:
                    break
                }
            })
            .disposed(by: bag)

        output.showMonthPicker
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] args in
                self?.showMonthPicker(firstYear: args.first, current: args.current, lastYear: args.last)
            })
            .disposed(by: bag)

        output.reloadSectionSet
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] type in
                guard let self else { return }
                switch type {
                case .internalChange(let indexSet):
                    UIView.performWithoutAnimation {
                        self.homeCalendarView.collectionView.reloadSections(indexSet)
                    }
                case .apiFetched(let indexSet):
                    self.homeCalendarView.collectionView.reloadSections(indexSet)
                }
            })
            .disposed(by: bag)

        output.profileImageFetched
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] data in
                self?.homeCalendarView.profileButton.fill(with: data)
            })
            .disposed(by: bag)

        output.showAlert
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] message in
                self?.showToast(message: message)
            })
            .disposed(by: bag)

        output.groupListFetched
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] groups in
                self?.setGroupButton(groups: groups)
            })
            .disposed(by: bag)

        output.didFinishRefreshing
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] _ in
                self?.didFetchRefreshedData.accept(())
            })
            .disposed(by: bag)
    }
}

// MARK: Calendar Move Actions
private extension HomeCalendarViewController {
    func jumpToIndex(index: Int) {
        observeScroll = false
        homeCalendarView.collectionView.contentOffset = CGPoint(x: CGFloat(index) * view.frame.width, y: 0)
        observeScroll = true
        movedToIndex.accept(.jump(index))
    }
    
    func initializeToIndex(centerIndex: Int) {
        homeCalendarView.collectionView.performBatchUpdates({
            homeCalendarView.collectionView.reloadData()
        }, completion: { [weak self] _ in
            guard let self else { return }
            homeCalendarView.collectionView.contentOffset = CGPoint(x: CGFloat(centerIndex) * self.view.frame.width, y: 0)
            homeCalendarView.collectionView.setAnimatedIsHidden(false, duration: 0.1)

            self.observeScroll = true
            movedToIndex.accept(.initialized(centerIndex))
        })
    }
}

// MARK: - Setting Group
private extension HomeCalendarViewController {
    func setGroupButton(groups: [GroupName]) {
        let image = UIImage(named: "groupCalendarList")
        let allAction = createGroupAction(title: "모아 보기", groupId: nil)
        let groupActions = groups.map { group in
            createGroupAction(title: group.groupName, groupId: group.groupId)
        }
        
        let buttonMenu = UIMenu(options: .displayInline, children: [allAction] + groupActions)
        
        let item = UIBarButtonItem(image: image, menu: buttonMenu)
        item.tintColor = .planusBlack
        navigationItem.setLeftBarButton(item, animated: true)
        homeCalendarView.groupListButton = item
    }

    func createGroupAction(title: String, groupId: Int?) -> UIAction {
        UIAction(title: title) { [weak self] _ in
            self?.isGroupSelectedWithId.accept(groupId)
        }
    }
}

// MARK: - show VC
private extension HomeCalendarViewController {
    func showMonthPicker(firstYear: Date, current: Date, lastYear: Date) {
        let vc = MonthPickerViewController(firstYear: firstYear, lastYear: lastYear, currentDate: current) { [weak self] date in
            self?.isMonthChanged.accept(date)
        }

        vc.preferredContentSize = CGSize(width: 320, height: 290)
        vc.modalPresentationStyle = .popover
        let popover: UIPopoverPresentationController = vc.popoverPresentationController!
        popover.delegate = self
        popover.sourceView = self.view
        let globalFrame = homeCalendarView.yearMonthButton.convert(homeCalendarView.yearMonthButton.bounds, to: nil)
        popover.sourceRect = CGRect(x: globalFrame.midX, y: globalFrame.maxY, width: 0, height: 0)
        popover.permittedArrowDirections = [.up]
        self.present(vc, animated: true, completion:nil)
    }
}

// MARK: - CollectionView DataSource, Delegate
extension HomeCalendarViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        viewModel.mainDays.count
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MonthlyCalendarCell.reuseIdentifier,
            for: indexPath
        ) as? MonthlyCalendarCell else { return UICollectionViewCell() }
        
        cell.fill(
            section: indexPath.section,
            viewModel: viewModel
        )

        cell.fill(
            nowMultipleSelecting: nowMultipleSelecting,
            multipleItemSelected: multipleItemSelected,
            itemSelected: itemSelected,
            refreshRequired: refreshRequired,
            didFetchRefreshedData: didFetchRefreshedData
        )
            
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let floatedIndex = scrollView.contentOffset.x/scrollView.bounds.width
        guard !(floatedIndex.isNaN || floatedIndex.isInfinite) && observeScroll else { return }
        movedToIndex.accept(.scroll(Int(round(floatedIndex))))
    }
}

// MARK: - PopoverPresentationDelegate
extension HomeCalendarViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
