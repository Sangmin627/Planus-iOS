//
//  MyGroupListSectionHeaderView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/31.
//

import UIKit

class MyGroupListSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "my-group-list-section-header-view"
    
    var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "Pretendard-Regular", size: 12)
        label.textColor = .planusDeepNavy
        label.isSkeletonable = true
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureView() {
        self.addSubview(titleLabel)
    }
    
    func configureLayout() {
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(12)
            $0.trailing.equalToSuperview().inset(12)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(14)
        }
    }
    
    func fill(title: String) {
        titleLabel.text = title
    }
}
