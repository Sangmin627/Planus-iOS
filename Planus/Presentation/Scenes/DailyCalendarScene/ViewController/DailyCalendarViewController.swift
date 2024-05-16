//
//  TodoDailyViewController.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/04/06.
//

import UIKit
import RxSwift
import RxCocoa

final class DailyCalendarViewController: UIViewController {
    
    private let bag = DisposeBag()
    private var viewModel: (any DailyCalendarViewModelable)?
    private var dailyCalendarView: DailyCalendarView?
    
    private let didTappedCompletionBtnAt = PublishRelay<IndexPath>()
    private let didDeleteTodoAt = PublishRelay<IndexPath>()
    private let viewDidDismissed = PublishRelay<Void>()
    private var isInteractable: Bool = true
    
    convenience init(viewModel: any DailyCalendarViewModelable) {
        self.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }
    
    override func loadView() {
        super.loadView()
        
        let view = DailyCalendarView(frame: self.view.frame)
        self.view = view
        self.dailyCalendarView = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureVC()
        bind()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.titleView = dailyCalendarView?.dateTitleButton
        navigationController?.presentationController?.delegate = self
    }
}

// MARK: - Configure
private extension DailyCalendarViewController {
    func configureVC() {
        dailyCalendarView?.collectionView.dataSource = self
        dailyCalendarView?.collectionView.delegate = self
    }
    
    func configureMode(mode: DailyCalendarSceneAuthority) {
        isInteractable = mode == .interactable
        
        switch mode {
        case .editable, .interactable:
            navigationItem.setRightBarButton(dailyCalendarView?.addTodoButton, animated: false)
        default:
            return
        }
    }
}

// MARK: - bind viewModel
private extension DailyCalendarViewController {
    func bind() {
        guard let viewModel,
              let dailyCalendarView else { return }

        let input = (any DailyCalendarViewModelable).Input(
            viewDidLoad: Observable.just(()),
            viewDidDismissed: viewDidDismissed.asObservable(),
            addTodoTapped: dailyCalendarView.addTodoButton.rx.tap.asObservable(),
            todoSelectedAt: dailyCalendarView.collectionView.rx.itemSelected.asObservable(),
            deleteTodoAt: didDeleteTodoAt.asObservable(),
            completeTodoAt: didTappedCompletionBtnAt.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        configureMode(mode: output.mode)
        
        dailyCalendarView.dateTitleButton.setTitle(output.currentDateText, for: .normal)
        
        output
            .nowLoading?
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                dailyCalendarView.spinner.isHidden = false
                dailyCalendarView.spinner.startAnimating()
                dailyCalendarView.collectionView.isHidden = true
            })
            .disposed(by: bag)

        output
            .needInsertItem?
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, indexPath in
                vc.insertTodoAt(indexPath: indexPath)
            })
            .disposed(by: bag)
            
        output
            .needDeleteItem?
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, indexPath in
                vc.deleteTodoAt(indexPath: indexPath)
            })
            .disposed(by: bag)
        
        output
            .needReloadData?
            .compactMap { $0 }
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                dailyCalendarView.collectionView.reloadData()
                print("reload??")
                if dailyCalendarView.spinner.isAnimating {
                    dailyCalendarView.spinner.setAnimatedIsHidden(true, duration: 0.2, onCompletion: {
                        dailyCalendarView.spinner.stopAnimating()
                        dailyCalendarView.collectionView.setAnimatedIsHidden(false, duration: 0.2)
                    })
                }
            })
            .disposed(by: bag)
        
        output
            .needUpdateItem?
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, args in
                let (removed, created) = args
                vc.updateTodo(removed: removed, created: created)
            })
            .disposed(by: bag)
        
        output
            .showAlert
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, message in
                vc.showToast(message: message)
            })
            .disposed(by: bag)
        
        
    }
}

// MARK: Actions
private extension DailyCalendarViewController {
    func insertTodoAt(indexPath: IndexPath) {
        guard let viewModel else { return }
        
        if viewModel.todoViewModels[indexPath.section].count == 1 {
            dailyCalendarView?.collectionView.reloadItems(at: [indexPath])
        } else {
            dailyCalendarView?.collectionView.insertItems(at: [indexPath])
        }
    }
    
    func deleteTodoAt(indexPath: IndexPath) {
        guard let viewModel else { return }
        
        if viewModel.todoViewModels[indexPath.section].count == 0 {
            dailyCalendarView?.collectionView.reloadItems(at: [indexPath])
        } else {
            dailyCalendarView?.collectionView.deleteItems(at: [indexPath])
        }
    }
    
    func updateTodo(removed: IndexPath, created: IndexPath) {
        if removed == created {
            dailyCalendarView?.collectionView.reloadItems(at: [created])
            return
        }
        
        dailyCalendarView?.collectionView.performBatchUpdates {
            deleteTodoAt(indexPath: removed)
            insertTodoAt(indexPath: created)
        }
    }
}

// MARK: - modal dismiss handler
extension DailyCalendarViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewDidDismissed.accept(())
    }
}

// MARK: - collection View
extension DailyCalendarViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return max(viewModel?.todoViewModels[section].count ?? 1, 1)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel else { return UICollectionViewCell() }
        
        guard !viewModel.todoViewModels[indexPath.section].isEmpty else {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: DailyCalendarEmptyTodoMockCell.reuseIdentifier,
                for: indexPath
            )
        }
        
        guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: DailyCalendarTodoCell.reuseIdentifier,
                for: indexPath
              ) as? DailyCalendarTodoCell else { return UICollectionViewCell() }
        
        let todoItem = viewModel.todoViewModels[indexPath.section][indexPath.item]

        cell.fill(
            title: todoItem.title,
            time: todoItem.startTime,
            category: todoItem.categoryColor,
            isGroup: todoItem.isGroupTodo,
            isPeriod: todoItem.isPeriodTodo,
            isMemo: todoItem.hasDescription,
            completion: todoItem.isCompleted,
            isInteractable: isInteractable
        )
        print(todoItem.title, todoItem.categoryColor) // 왜 안바뀌는 것인가??? 도대체???
        cell.fill { [weak self] in
            self?.didTappedCompletionBtnAt.accept(indexPath)
            Vibration.light.vibrate()
        }
        
        return cell
        

    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        viewModel?.todoViewModels.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        guard let type = DailyCalendarTodoType(rawValue: indexPath.section),
            let headerview = collectionView.dequeueReusableSupplementaryView(ofKind: DailyCalendarCollectionView.headerKind, withReuseIdentifier: DailyCalendarSectionHeaderSupplementaryView.reuseIdentifier, for: indexPath) as? DailyCalendarSectionHeaderSupplementaryView else { return UICollectionReusableView() }

        headerview.fill(title: type.title)
     
        return headerview
    }
}

extension DailyCalendarViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
