//
//  TodoDetailView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/25.
//

import UIKit
import RxSwift

class TodoDetailView: UIView {
    
    var bag = DisposeBag()
    
    var curtainView = UIView(frame: .zero)
    
    var upperView: UIView = {
        let view = UIView(frame: .zero)
        view.layer.cornerRadius = 10
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    var headerBarView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()
    
    var removeButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setTitle("삭제", for: .normal)
        button.titleLabel?.font = UIFont(name: "Pretendard-Bold", size: 16)
        button.setTitleColor(.planusTintRed, for: .normal)
        button.sizeToFit()
        return button
    }()
    
    var saveButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setTitle("저장", for: .normal)
        button.titleLabel?.font = UIFont(name: "Pretendard-Bold", size: 16)
        button.setTitleColor(.planusTintBlue, for: .normal)
        button.sizeToFit()
        return button
    }()
    
    var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "일정/할일 관리"
        label.font = UIFont(name: "Pretendard-Light", size: 16)
        label.sizeToFit()
        return label
    }()
    
    var contentView = UIView(frame: .zero)
        
    var titleView = TodoDetailTitleView(frame: .zero)
    var dateView = TodoDetailDateView(frame: .zero)
    var clockView = TodoDetailClockView(frame: .zero)
    var groupView = TodoDetailGroupView(frame: .zero)
    var memoView = TodoDetailMemoView(frame: .zero)
    var icnView = TodoDetailIcnView(frame: .zero)
    
    lazy var attributeViewGroup: [TodoDetailAttributeView] = [titleView, dateView, clockView, groupView, memoView]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureView() {
        self.addSubview(curtainView)
        
        self.addSubview(upperView)
        upperView.addSubview(headerBarView)
        headerBarView.addSubview(removeButton)
        headerBarView.addSubview(titleLabel)
        headerBarView.addSubview(saveButton)
        upperView.addSubview(titleView)
        upperView.addSubview(contentView)
        attributeViewGroup.filter { $0 != titleView }.forEach {
            contentView.addSubview($0)
            $0.alpha = 0
        }
        self.addSubview(icnView)
    }
    
    func configureLayout() {
        icnView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        upperView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(icnView.snp.top)
        }
        
        contentView.snp.makeConstraints {
            $0.bottom.leading.trailing.equalToSuperview()
        }
        
        
        titleView.snp.makeConstraints {
            $0.bottom.equalTo(contentView.snp.top)
            $0.leading.trailing.equalToSuperview()
        }
        
        attributeViewGroup.filter { $0 != titleView }.forEach {
            $0.snp.makeConstraints {
                $0.top.leading.trailing.equalToSuperview()
                
            }
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.bottomConstraint = $0.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            $0.bottomConstraint.isActive = false
        }
        
        
        headerBarView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(60)
            $0.bottom.equalTo(titleView.snp.top)
        }
        
        titleLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        
        saveButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
        }
        
        removeButton.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(20)
            $0.centerY.equalToSuperview()
        }
        
        curtainView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(headerBarView.snp.bottom)
            $0.bottom.equalToSuperview()
        }
    }
}

