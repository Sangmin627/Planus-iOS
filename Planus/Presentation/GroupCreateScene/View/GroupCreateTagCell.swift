//
//  GroupCreateTagCell.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/19.
//

import UIKit

class GroupCreateTagCell: UICollectionViewCell {
    static let reuseIdentifier = "group-create-tag-cell"
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseIn, animations: {
                    self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                })
            } else {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
                    self.transform = CGAffineTransform(scaleX: 1, y: 1)
                })
            }
        }
    }
    
    var removeBtnClosure: (() -> Void)?
    
    var label: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "Pretendard-Bold", size: 14)
        label.textColor = .white
        return label
    }()
    
    lazy var removeButton: UIButton = {
        let image = UIImage(named: "removeBtn") ?? UIImage()
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(removeBtnTapped), for: .touchUpInside)
        return button
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
        self.backgroundColor = UIColor(hex: 0x6495F4)
        self.layer.cornerRadius = 10
        self.layer.cornerCurve = .continuous
        
        self.addSubview(label)
        self.addSubview(removeButton)
    }
    
    func configureLayout() {
        label.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.equalToSuperview().inset(10)
        }
        
        removeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(10)
            $0.centerY.equalToSuperview()
            $0.leading.equalTo(label.snp.trailing).offset(6)
        }
    }
    
    func fill(tag: String) {
        self.label.text = tag
    }
    
    @objc func removeBtnTapped(_ sender: UIButton) {
        removeBtnClosure?()
    }
}
