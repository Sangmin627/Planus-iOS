//
//  DayPickerCollectionViewCell.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/29.
//

import UIKit

class DayPickerCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "day-picker-collection-view-cell"
    
    lazy var dayLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "Pretendard-Bold", size: 12)
        label.textColor = .planusBlack
        label.textAlignment = .center
        return label
    }()
    
    var leftHalfView: UIView = UIView(frame: .zero)
    var rightHalfView: UIView = UIView(frame: .zero)
    var highlightView: UIView = UIView(frame: .zero)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureView()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.highlightView.layer.cornerRadius = self.frame.height/2
    }
    
    func configureView() {
        self.addSubview(leftHalfView)
        self.addSubview(rightHalfView)
        self.addSubview(highlightView)
        highlightView.addSubview(dayLabel)
    }
    
    func configureLayout() {
        leftHalfView.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalToSuperview().dividedBy(2)
        }
        
        rightHalfView.snp.makeConstraints {
            $0.trailing.top.bottom.equalToSuperview()
            $0.width.equalToSuperview().dividedBy(2)
        }
        
        highlightView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        dayLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }
    
    func fill(day: String, state: MonthStateOfDay, rangeState: DayPickerModelRangeState) {
        dayLabel.text = day
        switch state {
        case .prev:
            dayLabel.textColor = .planusLightGray.withAlphaComponent(0.4)
        case .current:
            dayLabel.textColor = .planusBlack
        case .following:
            dayLabel.textColor = .planusLightGray.withAlphaComponent(0.4)
        }

        switch rangeState {
        case .only:
            self.highlightView.backgroundColor = .planusTintBlue
            self.leftHalfView.backgroundColor = nil
            self.rightHalfView.backgroundColor = nil
        case .start:
            self.highlightView.backgroundColor = .planusTintBlue
            self.leftHalfView.backgroundColor = nil
            self.rightHalfView.backgroundColor = .planusMediumGray
        case .end:
            self.highlightView.backgroundColor = .planusTintBlue
            self.leftHalfView.backgroundColor = .planusMediumGray
            self.rightHalfView.backgroundColor = nil
        case .inRange:
            self.leftHalfView.backgroundColor = .planusMediumGray
            self.rightHalfView.backgroundColor = .planusMediumGray
            self.highlightView.backgroundColor = nil
        case .none:
            self.highlightView.backgroundColor = nil
            self.leftHalfView.backgroundColor = nil
            self.rightHalfView.backgroundColor = nil
        }
    }
}
