//
//  TodoDailyViewController.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/06.
//

import UIKit
import RxSwift

class TodoDailyViewController: UIViewController {
    
    var bag = DisposeBag()
    var viewModel: TodoDailyViewModel?
    
    var didChangeDate = PublishSubject<Date>()
    
    lazy var dateTitleButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        button.titleLabel?.font = UIFont(name: "Pretendard-Bold", size: 18)
        button.setImage(UIImage(named: "downButton"), for: .normal)
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = .init(top: 0, left: 5, bottom: 0, right: -5)
        button.tintColor = .black
        button.setTitleColor(.black, for: .normal)
        button.addTarget(self, action: #selector(dateTitleBtnTapped), for: .touchUpInside)
        button.sizeToFit()
        return button
    }()
    
    lazy var addTodoButton: UIBarButtonItem = {
        let image = UIImage(named: "plusBtn")
        let item = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(addTodoTapped))
        item.tintColor = .black
        return item
    }()
    
    lazy var collectionView: TodoDailyCollectionView = {
        let cv = TodoDailyCollectionView(frame: .zero)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()
    
    convenience init(viewModel: TodoDailyViewModel) {
        self.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
        configureLayout()
        
        bind()
        
        navigationItem.setRightBarButton(addTodoButton, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.titleView = dateTitleButton
    }
    
    func bind() {
        guard let viewModel else { return }
        
        let input = TodoDailyViewModel.Input(didChangedDate: didChangeDate)
        
        let output = viewModel.transform(input: input)
        
        output
            .didUpdateDateText
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, dateString in
                vc.dateTitleButton.setTitle(dateString, for: .normal)
            })
            .disposed(by: bag)
        
        output
            .didRequestTodoList
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                
            })
            .disposed(by: bag)
        
        output
            .didFetchTodoList
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                vc.collectionView.reloadData()
            })
            .disposed(by: bag)
    }
    
    func configureView() {
        self.view.backgroundColor = UIColor(hex: 0xF5F5FB)
        self.view.addSubview(collectionView)
    }
    
    func configureLayout() {
        dateTitleButton.snp.makeConstraints {
            $0.width.equalTo(160)
        }
        collectionView.snp.makeConstraints {
            $0.top.equalTo(self.view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    @objc func addTodoTapped(_ sender: UIButton) {
        let bottomSheetVC = TodoDetailViewController()
        bottomSheetVC.modalPresentationStyle = .overFullScreen
        self.present(bottomSheetVC, animated: false, completion: nil)
    }
    
    @objc func dateTitleBtnTapped(_ sender: UIButton) {
        showSmallCalendar()
    }
    
    private func showSmallCalendar() {
        
        guard let viewModel = self.viewModel,
              let currentDate = try? viewModel.currentDate.value() else {
            return
        }

        if let sheet = self.sheetPresentationController {
            sheet.invalidateDetents()
        }
        
        let vm = SmallCalendarViewModel()
        vm.completionHandler = { [weak self] date in
            self?.didChangeDate.onNext(date)
        }
        vm.configureDate(currentDate: currentDate, min: viewModel.minDate ?? Date(), max: viewModel.maxDate ?? Date())
        let vc = SmallCalendarViewController(viewModel: vm)

        vc.preferredContentSize = CGSize(width: 320, height: 400)
        vc.modalPresentationStyle = .popover

        let popover: UIPopoverPresentationController = vc.popoverPresentationController!
        popover.delegate = self
        popover.sourceView = self.view
        popover.sourceItem = dateTitleButton

        present(vc, animated: true, completion:nil)
    }
}

extension TodoDailyViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return viewModel?.scheduledTodoList?.count ?? 0
        case 1:
            return viewModel?.unscheduledTodoList?.count ?? 0
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BigTodoCell.reuseIdentifier, for: indexPath) as? BigTodoCell else { return UICollectionViewCell() }
        
        var todoItem: Todo?
        switch indexPath.section {
        case 0:
            todoItem = viewModel?.scheduledTodoList?[indexPath.item]
        case 1:
            todoItem = viewModel?.unscheduledTodoList?[indexPath.item]
        default:
            return UICollectionViewCell()
        }
        guard let todoItem else { return UICollectionViewCell() }
        cell.fill(title: todoItem.title, time: nil, category: todoItem.category)
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        guard let headerview = collectionView.dequeueReusableSupplementaryView(ofKind: TodoDailyCollectionView.headerKind, withReuseIdentifier: TodoSectionHeaderSupplementaryView.reuseIdentifier, for: indexPath) as? TodoSectionHeaderSupplementaryView else { return UICollectionReusableView() }
        
        var title: String
        switch indexPath.section {
        case 0:
            title = "일정"
        case 1:
            title = "투두"
        default:
            return UICollectionReusableView()
        }
        headerview.fill(title: title)
     
        return headerview
    }
}

extension TodoDailyViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
