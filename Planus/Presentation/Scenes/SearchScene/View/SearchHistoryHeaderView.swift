//
//  SearchHistoryHeaderView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/27.
//

import UIKit

class SearchHistoryHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "search-history-header-view"
    
    var closure: (() -> Void)?
    var label: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "Pretendard-SemiBold", size: 14)
        label.textColor = .planusBlack
        label.text = "최근 검색어"
        return label
    }()
    
    lazy var removeAllBtn: UIButton = {
        let button = SpringableButton(frame: .zero)
        button.setTitle("모두 지우기", for: .normal)
        button.titleLabel?.font = UIFont(name: "Pretendard-Regular", size: 14)
        button.setTitleColor(.darkGray, for: .normal)
        button.addTarget(self, action: #selector(removeAllBtnTapped), for: .touchUpInside)
        return button
    }()
    
    @objc func removeAllBtnTapped(_ sender: UIButton) {
        closure?()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureView() {
        self.addSubview(label)
        self.addSubview(removeAllBtn)
    }
    
    func configureLayout() {
        label.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview()
        }
        
        removeAllBtn.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview()
        }
    }
}
