//
//  MonthlyCalendarCell.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/25.
//

import UIKit
import RxSwift

class MonthlyCalendarCell: UICollectionViewCell {
    
    static let reuseIdentifier = "monthly-calendar-cell"
    
    var viewModel: HomeCalendarViewModel?
    
    var selectionState: Bool = false
    var firstPressedIndexPath: IndexPath?
    var lastPressedIndexPath: IndexPath?
    var section: Int?
    
    var isMultipleSelecting: PublishSubject<Bool>?
    var isMultipleSelected: PublishSubject<(Int, (Int, Int))>?
    var isSingleSelected: PublishSubject<(Int, Int)>?
    
    var bag: DisposeBag?
    
    lazy var lpgr : UILongPressGestureRecognizer = {
        let lpgr = UILongPressGestureRecognizer(target: self, action: #selector(self.longTap(_:)))
        lpgr.minimumPressDuration = 0.5
        lpgr.delegate = self
        lpgr.delaysTouchesBegan = true
        return lpgr
    }()
    
    lazy var pgr: UIPanGestureRecognizer = {
        let pgr = UIPanGestureRecognizer(target: self, action: #selector(self.drag(_:)))
        pgr.delegate = self
        return pgr
    }()
    
    func configureGestureRecognizer() {
        self.collectionView.addGestureRecognizer(lpgr)
        self.collectionView.addGestureRecognizer(pgr)
    }
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        configureGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    func configureView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor(hex: 0xF5F5FB)
        collectionView.showsVerticalScrollIndicator = false
        self.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        collectionView.register(DailyCalendarCell.self, forCellWithReuseIdentifier: DailyCalendarCell.identifier)
    }
    
    func fill(section: Int, viewModel: HomeCalendarViewModel?) {
        self.section = section
        self.viewModel = viewModel
        collectionView.reloadData()
    }
    
    func fill(
        isMultipleSelecting: PublishSubject<Bool>,
        isMultipleSelected: PublishSubject<(Int, (Int, Int))>,
        isSingleSelected: PublishSubject<(Int, Int)>
    ) {
        self.isMultipleSelecting = isMultipleSelecting
        self.isMultipleSelected = isMultipleSelected
        self.isSingleSelected = isSingleSelected
    }
}

extension MonthlyCalendarCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = self.section else { return Int() }
        return viewModel?.mainDayList[section].count ?? Int()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section,
              let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DailyCalendarCell.identifier, for: indexPath) as? DailyCalendarCell,
              let dayViewModel = viewModel?.mainDayList[section][indexPath.item] else {
            print("여긴가1?")
            return UICollectionViewCell()
        }
        
        cell.fill(
            delegate: self,
            day: "\(Calendar.current.component(.day, from: dayViewModel.date))",
            state: dayViewModel.state,
            weekDay: WeekDay(rawValue: (Calendar.current.component(.weekday, from: dayViewModel.date)+5)%7)!,
            todoList: dayViewModel.todoList
        ) //카테고리색을 어케하지??? 싱글턴 딕셔너리 개마렵다 ㅋㅋㅋ,,,,,,,,........

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let section,
              let maxTodoViewModel = viewModel?.getMaxInWeek(indexPath: IndexPath(item: indexPath.item, section: section)) else { return CGSize() }
        
        let screenWidth = UIScreen.main.bounds.width
                
        var todoCount = maxTodoViewModel.todoList.count
        
        if let height = viewModel?.cachedCellHeightForTodoCount[todoCount] {
            return CGSize(width: Double(1)/Double(7) * Double(screenWidth), height: Double(height))
            
        } else {
            let mockCell = DailyCalendarCell(mockFrame: CGRect(x: 0, y: 0, width: Double(1)/Double(7) * screenWidth, height: 116))
            mockCell.fill(todoList: maxTodoViewModel.todoList)

            mockCell.layoutIfNeeded()
            
            let estimatedSize = mockCell.systemLayoutSizeFitting(CGSize(width: Double(1)/Double(7) * screenWidth, height: 116))
            viewModel?.cachedCellHeightForTodoCount[todoCount] = estimatedSize.height
            return CGSize(width: Double(1)/Double(7) * screenWidth, height: estimatedSize.height)
            
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if let section {
            isSingleSelected?.onNext((section, indexPath.item))
        }
        return false
    }
    
}

extension MonthlyCalendarCell {
    @objc func longTap(_ gestureRecognizer: UILongPressGestureRecognizer){
        if gestureRecognizer.state == .began {
            let location = gestureRecognizer.location(in: collectionView)
            guard let nowIndexPath = collectionView.indexPathForItem(at: location) else { return }
            
            selectionState = true

            self.firstPressedIndexPath = nowIndexPath
            self.lastPressedIndexPath = nowIndexPath
            collectionView.selectItem(at: nowIndexPath, animated: true, scrollPosition: [])
        }
    }
    
    // 이부분을 간소화 해야함
    @objc func drag(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard self.selectionState else {
            self.isMultipleSelecting?.onNext(false)
            collectionView.isScrollEnabled = true
            collectionView.isUserInteractionEnabled = true
            return
        }
        let location = gestureRecognizer.location(in: collectionView)

        guard let nowIndexPath = collectionView.indexPathForItem(at: location) else { return }
        switch gestureRecognizer.state {
        case .began:
            isMultipleSelecting?.onNext(true)
            collectionView.isScrollEnabled = false
            collectionView.isUserInteractionEnabled = false
            collectionView.allowsMultipleSelection = true
        case .changed:
            guard let firstPressedIndexPath = firstPressedIndexPath,
                  let lastPressedIndexPath = lastPressedIndexPath,
                  nowIndexPath != lastPressedIndexPath else { return }
            
            if firstPressedIndexPath.item < lastPressedIndexPath.item {
                if firstPressedIndexPath.item > nowIndexPath.item {
                    (firstPressedIndexPath.item+1...lastPressedIndexPath.item).forEach {
                        self.collectionView.deselectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true)
                    }
                    (nowIndexPath.item..<firstPressedIndexPath.item).forEach {
                        self.collectionView.selectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true, scrollPosition: [])
                    }
                } else if nowIndexPath.item < lastPressedIndexPath.item {
                    (nowIndexPath.item+1...lastPressedIndexPath.item).forEach {
                        self.collectionView.deselectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true)
                    }
                } else if nowIndexPath.item > lastPressedIndexPath.item {
                    (lastPressedIndexPath.item+1...nowIndexPath.item).forEach {
                        self.collectionView.selectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true, scrollPosition: [])
                    }
                }
            } else if (firstPressedIndexPath.item > lastPressedIndexPath.item) {
                if (firstPressedIndexPath.item < nowIndexPath.item) {

                    (lastPressedIndexPath.item..<firstPressedIndexPath.item).forEach {
                        self.collectionView.deselectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true)
                    }
                    (firstPressedIndexPath.item+1...nowIndexPath.item).forEach {
                        self.collectionView.selectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true, scrollPosition: [])
                    }
                } else if lastPressedIndexPath.item < nowIndexPath.item {

                    (lastPressedIndexPath.item..<nowIndexPath.item).forEach {
                        self.collectionView.deselectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true)
                    }
                } else if nowIndexPath.item < lastPressedIndexPath.item {

                    (nowIndexPath.item..<lastPressedIndexPath.item).forEach {
                        self.collectionView.selectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true, scrollPosition: [])
                    }
                }
            } else {
                if nowIndexPath.item > lastPressedIndexPath.item {

                    (lastPressedIndexPath.item+1...nowIndexPath.item).forEach {
                        self.collectionView.selectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true, scrollPosition: [])
                    }
                } else {

                    (nowIndexPath.item..<lastPressedIndexPath.item).forEach {
                        self.collectionView.selectItem(at: IndexPath(item: $0, section: firstPressedIndexPath.section), animated: true, scrollPosition: [])
                    }
                }
            }
            
            self.lastPressedIndexPath = nowIndexPath
        case .ended:
            selectionState = false
            
            guard let section,
                  let firstPressedItem = self.firstPressedIndexPath?.item,
                  let lastPressedItem = self.lastPressedIndexPath?.item else { return }
            self.isMultipleSelected?.onNext((section, (firstPressedItem, lastPressedItem)))

            firstPressedIndexPath = nil
            lastPressedIndexPath = nil
            
            self.isMultipleSelecting?.onNext(false)
            

            collectionView.isScrollEnabled = true
            collectionView.isUserInteractionEnabled = true
            collectionView.allowsMultipleSelection = false
            
            guard let paths = self.collectionView.indexPathsForSelectedItems else { return }
            paths.forEach { indexPath in
                self.collectionView.deselectItem(at: indexPath, animated: true)
            }
        default:
            print(gestureRecognizer.state)
        }
    }
}

// MARK: GestureRecognizerDelegate

extension MonthlyCalendarCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension MonthlyCalendarCell: DailyCalendarCellDelegate {
    func dailyCalendarCell(_ dayCalendarCell: DailyCalendarCell, colorOfCategoryId id: Int) -> CategoryColor? {
        return viewModel?.categoryDict[id]?.color
    }
}
