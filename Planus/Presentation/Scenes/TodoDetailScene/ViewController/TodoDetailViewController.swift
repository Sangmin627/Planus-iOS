//
//  TodoDetailViewController.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/28.
//

import UIKit
import RxSwift
import RxCocoa

final class TodoDetailViewController: UIViewController {
    private let bag = DisposeBag()
    private var viewModel: (any TodoDetailViewModelable)?
    
    private var isFirstAppear = true
    private var currentKeyboardHeight: CGFloat = 0
    private var mode: TodoDetailSceneAuthority?
    
    // MARK: UI Event
    private let didSelectedDateRange = PublishRelay<DateRange>()
    private let didSelectedGroupAt = PublishRelay<Int?>()
    private let didChangedTimeValue = PublishRelay<String?>()
    private let needDismiss = PublishRelay<Void>()
    private let showMessage = PublishRelay<Message>()
            
    // MARK: Child ViewController
    private let dayPickerViewController = DayPickerViewController(nibName: nil, bundle: nil)
    
    // MARK: Child View
    private let todoDetailView = TodoDetailView(frame: .zero)
    
    // MARK: Background
    private let dimmedView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.darkGray.withAlphaComponent(0)
        return view
    }()
    
    convenience init(viewModel: any TodoDetailViewModelable) {
        self.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureView()
        configureLayout()
        
        bind()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        configureKeyboard()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if isFirstAppear {
            self.animateFirstAppearance()
        }
    }
}

// MARK: - bind viewModel
private extension TodoDetailViewController {
    func bind() {
        guard let viewModel else { return }
        
        let input = (any TodoDetailViewModelable).Input(
            titleTextChanged: todoDetailView.titleView.todoTitleField.rx.text.skip(1).asObservable(),
            dayRange: didSelectedDateRange.distinctUntilChanged().asObservable(),
            timeFieldChanged: didChangedTimeValue.asObservable(),
            groupSelectedAt: didSelectedGroupAt.distinctUntilChanged().asObservable(),
            memoTextChanged: todoDetailView.memoView.memoObservable,
            categoryBtnTapped: todoDetailView.titleView.categoryButton.rx.tap.asObservable(),
            todoSaveBtnTapped: todoDetailView.saveButton.rx.tap.throttle(.seconds(1), scheduler: MainScheduler.asyncInstance).asObservable(),
            todoRemoveBtnTapped: todoDetailView.removeButton.rx.tap.throttle(.seconds(1), scheduler: MainScheduler.asyncInstance).asObservable(),
            needDismiss: needDismiss.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        setMode(mode: output.mode)
        
        output
            .titleValueChanged
            .bind(to: todoDetailView.titleView.todoTitleField.rx.text)
            .disposed(by: bag)
        
        output
            .memoValueChanged
            .observe(on: MainScheduler.instance)
            .withUnretained(self)
            .subscribe(onNext: { vc, text in
                vc.setMemoValue(text: text)
            })
            .disposed(by: bag)
        
        output
            .dayRangeChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] range in
                self?.dayPickerViewController.setDate(startDate: range.start, endDate: range.end)
            })
            .disposed(by: bag)
        
        output
            .timeValueChanged
            .observe(on: MainScheduler.instance)
            .withUnretained(self)
            .subscribe(onNext: { vc, time in
                vc.setTimeValue(time: time)
            })
            .disposed(by: bag)
        
        output
            .categoryChanged
            .withUnretained(self)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { vc, category in
                vc.setCategory(category: category)
            })
            .disposed(by: bag)
        
        output
            .groupChangedToIndex
            .withUnretained(self)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { vc, index in
                vc.setGroup(at: index)
            })
            .disposed(by: bag)
        
        output
            .showMessage
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, message in
                vc.showToast(message: message, fromBotton: vc.currentKeyboardHeight + 30)
            })
            .disposed(by: bag)
        
        output
            .showSaveConstMessagePopUp
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                vc.showPopUp(
                    title: "일정, 카테고리는 필수에요",
                    message: "가끔 멘트가\n떠오르지 않을 때도 있죠 😌",
                    alertAttrs: [CustomAlertAttr(title: "확인", actionHandler: {}, type: .normal)]
                )
            })
            .disposed(by: bag)
        
        output
            .dismissRequired
            .observe(on: MainScheduler.asyncInstance)
            .withUnretained(self)
            .subscribe(onNext: { vc, _ in
                vc.animateDismiss()
            })
            .disposed(by: bag)
        
        viewModel.fetch()
    }
}

// MARK: - Set View Components
private extension TodoDetailViewController {
    func setMode(mode: TodoDetailSceneAuthority) {
        self.mode = mode
        self.todoDetailView.icnView.setMode(mode: mode)
        
        switch mode {
        case .editablePrivate, .editablePublic:
            todoDetailView.removeButton.isHidden = false
            todoDetailView.titleView.todoTitleField.becomeFirstResponder()
        case .newPrivate, .newPublic:
            todoDetailView.removeButton.isHidden = true
            todoDetailView.titleView.todoTitleField.becomeFirstResponder()
        case .viewable:
            todoDetailView.removeButton.isHidden = true
            todoDetailView.saveButton.isHidden = true
            dayPickerViewController.view.isHidden = true
            
            todoDetailView.attributeViewGroup.forEach {
                $0.isUserInteractionEnabled = false
            }
            
            todoDetailView.icnView.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalToSuperview().inset(34) // homeIndicator height
            }
        default:
            return
        }
    }
    
    func setMemoValue(text: String?) {
        let memoAttrIndex = TodoDetailAttribute.memo.rawValue
        todoDetailView.icnView.buttonList[memoAttrIndex].tintColor = (text == nil) ? .gray : .planusBlack
        if mode == .viewable {
            todoDetailView.icnView.buttonList[memoAttrIndex].isUserInteractionEnabled = text != nil
        }
        
        todoDetailView.memoView.memoTextView.text = text
    }
    
    func setTimeValue(time: String?) {
        let clockAttrIndex = TodoDetailAttribute.clock.rawValue
        todoDetailView.icnView.buttonList[clockAttrIndex].tintColor = (time == nil) ? .gray : .planusBlack
        if mode == .viewable {
            todoDetailView.icnView.buttonList[clockAttrIndex].isUserInteractionEnabled = time != nil
        }

        guard let time else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat =  "HH:mm"
        
        let date = dateFormatter.date(from: time)!
        
        todoDetailView.clockView.timePicker.date = date
    }
    
    func setCategory(category: Category?) {
        if let category {
            todoDetailView.titleView.categoryButton.categoryLabel.text = category.title
            todoDetailView.titleView.categoryButton.categoryLabel.textColor = .planusBlack
            todoDetailView.titleView.categoryButton.categoryColorView.backgroundColor = category.color.todoForCalendarColor
        } else {
            todoDetailView.titleView.categoryButton.categoryLabel.text = "카테고리 선택"
            todoDetailView.titleView.categoryButton.categoryLabel.textColor = .planusLightGray
            todoDetailView.titleView.categoryButton.categoryColorView.backgroundColor = .gray
        }
    }
    
    func setGroup(at index: Int?) {
        let groupAttrIndex = TodoDetailAttribute.group.rawValue
        todoDetailView.icnView.buttonList[groupAttrIndex].tintColor = (index == nil) ? .gray : .planusBlack
        if mode == .viewable {
            todoDetailView.icnView.buttonList[groupAttrIndex].isUserInteractionEnabled = index != nil
        }

        guard let index else { return }
        todoDetailView.groupView.groupPickerView.selectRow(index, inComponent: 0, animated: false)
    }
}

// MARK: configure VC
private extension TodoDetailViewController {
    func configureAddTodoView() {
        dayPickerViewController.delegate = self
        
        todoDetailView.icnView.delegate = self
        todoDetailView.groupView.groupPickerView.dataSource = self
        todoDetailView.groupView.groupPickerView.delegate = self
        
        todoDetailView.clockView.timePicker.addTarget(self, action: #selector(didChangeTime), for: .valueChanged)
        
        todoDetailView.addSubview(dayPickerViewController.view)
    }
    
    func configureDimmmedView() {
        let dimmedTap = UITapGestureRecognizer(target: self, action: #selector(dimmedViewTapped(_:)))
        dimmedView.addGestureRecognizer(dimmedTap)
        dimmedView.isUserInteractionEnabled = true
    }
    
    func configureView() {
        self.view.addSubview(dimmedView)
        self.view.addSubview(todoDetailView)
        
        [todoDetailView.upperView,
         todoDetailView.icnView,
         dayPickerViewController.view,
         todoDetailView.curtainView].forEach {
            $0?.backgroundColor = .planusBackgroundColor
        }

        configureAddTodoView()
        configureDimmmedView()
    }
    
    func configureLayout() {
        dimmedView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        todoDetailView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(self.view.snp.bottom)
            $0.height.lessThanOrEqualTo(700)
        }

        dayPickerViewController.view.snp.makeConstraints {
            $0.top.equalTo(todoDetailView.icnView.snp.bottom)
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.height.equalTo(300)
            $0.bottom.equalToSuperview()
        }
        
    }
    
    func configureKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Attribute Icn Views Actions
extension TodoDetailViewController: TodoDetailIcnViewDelegate {
    func deactivate(attr: TodoDetailAttribute) {
        switch attr {
        case .title:
            todoDetailView.titleView.todoTitleField.text = nil
        case .calendar:
            dayPickerViewController.setDate(startDate: nil, endDate: nil)
        case .clock:
            didChangedTimeValue.accept(nil)
        case .group:
            didSelectedGroupAt.accept(nil)
        case .memo:
            todoDetailView.memoView.isMemoActive.accept(false)
            todoDetailView.memoView.memoTextView.text = nil
        }
    }
    
    func move(from: TodoDetailAttribute, to: TodoDetailAttribute) {
        guard from != to else { return }

        // Attribute 변경에 따른 애니메이션 처리
        animateAttributeChange(from: from, to: to)

        // 모드에 따라서 추가 동작 수행
        if self.mode != .viewable {
            switch to {
            case .title:
                todoDetailView.titleView.todoTitleField.becomeFirstResponder()
            case .calendar:
                self.view.endEditing(true)
            case .clock:
                todoDetailView.titleView.todoTitleField.becomeFirstResponder()
                didChangeTime(todoDetailView.clockView.timePicker)
            case .group:
                todoDetailView.titleView.todoTitleField.becomeFirstResponder()
                let index = todoDetailView.groupView.groupPickerView.selectedRow(inComponent: 0)
                didSelectedGroupAt.accept(index)
            case .memo:
                todoDetailView.memoView.isMemoActive.accept(true)
                todoDetailView.memoView.memoTextView.becomeFirstResponder()
            }
        }
    }

    private func animateAttributeChange(from: TodoDetailAttribute, to: TodoDetailAttribute) {
        if to != .title {
            todoDetailView.titleView.set1line()
        } else {
            todoDetailView.titleView.set2lines()
        }

        if from != .title {
            self.todoDetailView.attributeViewGroup[from.rawValue].bottomConstraint.isActive = false
        }
        if to != .title {
            let newAnchor = self.todoDetailView.attributeViewGroup[to.rawValue].bottomAnchor.constraint(equalTo: self.todoDetailView.contentView.bottomAnchor)
            self.todoDetailView.attributeViewGroup[to.rawValue].bottomConstraint = newAnchor
            newAnchor.isActive = true
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            if from != .title {
                self.todoDetailView.attributeViewGroup[from.rawValue].alpha = 0
            }
            if to != .title {
                self.todoDetailView.attributeViewGroup[to.rawValue].alpha = 1
            }
            self.todoDetailView.upperView.layoutIfNeeded()
        })
    }
}

// MARK: - dimmed View Tap animation
private extension TodoDetailViewController {
    @objc
    func dimmedViewTapped(_ sender: UITapGestureRecognizer) {
        animateDismiss()
    }
    
    func animateDismiss() {
        self.view.endEditing(true)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.dimmedView.alpha = 0.0
            self.todoDetailView.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.top.equalTo(self.dimmedView.snp.bottom)
                $0.height.lessThanOrEqualTo(700)
            }
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.needDismiss.accept(())
        })
    }
}

// MARK: - View first Appearance Animation
private extension TodoDetailViewController {
    func animateFirstAppearance() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: {
            self.todoDetailView.snp.remakeConstraints {
                $0.bottom.leading.trailing.equalToSuperview()
                $0.height.lessThanOrEqualTo(700)
            }
            self.dimmedView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.7)
            self.view.layoutIfNeeded()
        }, completion: nil)
        isFirstAppear = false
    }
}

// MARK: - Keyboard Notification Actions
private extension TodoDetailViewController {
    @objc func keyboardWillShow(_ notification:NSNotification) {
        if let keyboardFrame: NSValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardRectangle = keyboardFrame.cgRectValue
            let keyboardHeight = keyboardRectangle.height

            currentKeyboardHeight = keyboardHeight
            
            dayPickerViewController.view.snp.remakeConstraints {
                $0.top.equalTo(todoDetailView.icnView.snp.bottom)
                $0.leading.trailing.equalToSuperview().inset(10)
                $0.height.equalTo(keyboardHeight)
                $0.bottom.equalToSuperview()
            }
            
            UIView.animate(withDuration: 0.2, delay: 0, animations: {
                self.view.layoutIfNeeded()
            })
        }
    }

    @objc func keyboardWillHide(_ notification:NSNotification) {
        currentKeyboardHeight = 0
        
        UIView.animate(withDuration: 0.2, delay: 0, animations: {
            self.view.layoutIfNeeded()
        })
        
    }
}

// MARK: - DayPickerVC Delegate (Date)
extension TodoDetailViewController: DayPickerViewControllerDelegate {
    func dayPickerViewController(_ dayPickerViewController: DayPickerViewController, didSelectDate: Date) {
        todoDetailView.dateView.setDate(startDate: dayPickerViewController.dateFormatter2.string(from: didSelectDate))
        didSelectedDateRange.accept(DateRange(start: didSelectDate))
    }
    
    func unHighlightAllItem(_ dayPickerViewController: DayPickerViewController) {
        todoDetailView.dateView.setDate()
        didSelectedDateRange.accept(DateRange())
    }
    
    func dayPickerViewController(_ dayPickerViewController: DayPickerViewController, didSelectDateInRange: (Date, Date)) {
        let (a, b) = didSelectDateInRange
        
        let min = min(a, b)
        let max = max(a, b)
        todoDetailView.dateView.setDate(
            startDate: dayPickerViewController.dateFormatter2.string(from: min),
            endDate: dayPickerViewController.dateFormatter2.string(from: max)
        )

        didSelectedDateRange.accept(DateRange(start: min, end: max))
    }
}

// MARK: - Picker DataSource, Delegate (group)
extension TodoDetailViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return viewModel?.groups.count ?? 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return viewModel?.groups[row].groupName
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        didSelectedGroupAt.accept(row)
    }
}

// MARK: Date Picker (time)
private extension TodoDetailViewController {
    @objc func didChangeTime(_ sender: UIDatePicker) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let dateStr = dateFormatter.string(from: sender.date)
        
        didChangedTimeValue.accept(dateStr)
    }
}
