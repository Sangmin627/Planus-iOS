//
//  TodoDetailMemoView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/23.
//

import UIKit
import RxSwift

class TodoDetailMemoView: UIView {
    var bag = DisposeBag()
    
    lazy var memoHeightConstraint: NSLayoutConstraint = {
        return memoTextView.heightAnchor.constraint(equalToConstant: 70)
    }()
    
    let memoInitHeight: CGFloat = 30
    let memoMaxHeight: CGFloat = 90
    
    lazy var memoTextView: PlaceholderTextView = {
        let textView = PlaceholderTextView(frame: .zero)
        textView.textContainer.lineFragmentPadding = 0
        textView.text = ""
        textView.placeholder = "메모를 입력하세요"
        textView.placeholderColor = UIColor(hex: 0xBFC7D7)
        textView.textContainerInset = .init(top: 10, left: 10, bottom: 10, right: 10)
        textView.textColor = .black
        textView.backgroundColor = UIColor(hex: 0xF5F5FB)
        textView.font = UIFont(name: "Pretendard-Regular", size: 16)
        textView.delegate = self
        textView.layer.borderWidth = 1
        textView.layer.cornerCurve = .continuous
        textView.layer.cornerRadius = 10
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        return textView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        configureLayout()
        
        bind()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bind() {
        memoTextView.rx.text
            .compactMap { $0 }
            .subscribe(onNext: { text in
                self.layoutTextViewLines()
                self.memoTextView.layer.borderColor = text.isEmpty ?
                UIColor(hex: 0xBFC7D7).cgColor : UIColor(hex: 0xADC5F8).cgColor
            })
            .disposed(by: bag)
    }
    
    func configureView() {
        self.addSubview(memoTextView)
    }
    
    func configureLayout() {
        memoTextView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.bottom.equalToSuperview().inset(20)
            $0.height.greaterThanOrEqualTo(20)
        }
    }
}


extension TodoDetailMemoView: UITextViewDelegate {
    func layoutTextViewLines() {
        let lines = memoTextView.numberOfLines
        if lines >= 4 {
            memoTextView.isScrollEnabled = true
            memoHeightConstraint.isActive = true
        } else {
            memoTextView.isScrollEnabled = false
            memoHeightConstraint.isActive = false
            memoTextView.sizeToFit()
        }
        memoTextView.layoutIfNeeded()
    }
}
