//
//  SmallTodoView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/25.
//

import UIKit

final class SmallTodoView: UIView {
    private let leadingView: UIView = {
        let view = UIView(frame: .zero)
        return view
    }()
    
    private let toDoLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "Pretendard-Regular", size: 11)
        label.textAlignment = .center
        label.lineBreakMode = .byCharWrapping
        return label
    }()
    
    convenience init(title: String, categoryColor: CategoryColor, isComplete: Bool?) {
        self.init(frame: .zero)
        
        fill(title: title, categoryColor: categoryColor, isComplete: isComplete)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private func configureView() {
        self.layer.cornerRadius = 3
        self.layer.cornerCurve = .continuous
        self.clipsToBounds = true
        self.addSubview(leadingView)
        self.addSubview(toDoLabel)
    }
    
    private func configureLayout() {
        leadingView.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalTo(2)
            
        }
        toDoLabel.snp.makeConstraints {
            $0.leading.equalTo(leadingView.snp.trailing).offset(1)
            $0.trailing.equalToSuperview().inset(2)
            $0.centerY.equalToSuperview()
        }
    }
    
    func fill(title: String, categoryColor: CategoryColor, isComplete: Bool?) {
        self.toDoLabel.text = title
        self.leadingView.backgroundColor = categoryColor.todoLeadingColor
        self.backgroundColor = categoryColor.todoForCalendarColor
        self.toDoLabel.textColor = categoryColor.todoThickColor
        
        if let isComplete,
           isComplete {
            self.leadingView.isHidden = true
        }

    }
}
