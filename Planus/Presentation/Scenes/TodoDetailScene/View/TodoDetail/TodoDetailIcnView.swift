//
//  TodoDetailIcnView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/08/23.
//

import UIKit

enum TodoDetailAttribute: Int, CaseIterable {
    case title = 0
    case calendar
    case clock
    case group
    case memo
    
    var imageName: String {
        switch self {
        case .title:
            return "detailTitleBtn"
        case .calendar:
            return "detailCalendarBtn"
        case .clock:
            return "detailClockBtn"
        case .group:
            return "detailGroupBtn"
        case .memo:
            return "detailMemoBtn"
        }
    }
}

final class TodoDetailIcnView: UIView {
    weak var delegate: TodoDetailIcnViewDelegate?
    
    private var mode: TodoDetailSceneAuthority?
    var viewingAttr: TodoDetailAttribute = .title
    
    var stackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.alignment = .center
        return stackView
    }()
    
    lazy var buttonList: [UIButton] = { [weak self] in
        TodoDetailAttribute.allCases.map { [weak self] attr in
            let image = UIImage(named: attr.imageName)?.withRenderingMode(.alwaysTemplate) ?? UIImage()
            let button = UIButton(frame: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            button.tag = attr.rawValue
            button.setImage(image, for: .normal)
            button.addTarget(self, action: #selector(btnTapped), for: .touchUpInside)
            button.tintColor = (attr == .title || attr == .calendar) ? .planusBlack : .gray
            return button
        }
    }()
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        
        configureView()
        configureLayout()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setMode(mode: TodoDetailSceneAuthority) {
        self.mode = mode
    }
    
    func configureView() {
        self.addSubview(stackView)
        
        buttonList.forEach {
            stackView.addArrangedSubview($0)
        }
    }
    
    func configureLayout() {
        stackView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(19)
            $0.trailing.lessThanOrEqualToSuperview().inset(19)
            $0.height.equalTo(30)
            $0.top.bottom.equalToSuperview().inset(5)
        }
    }

    @objc func btnTapped(_ sender: UIButton) {
        let index = sender.tag
        guard let mode,
              var selectedAttr = TodoDetailAttribute(rawValue: index) else { return }
        
        if selectedAttr == viewingAttr,
           (selectedAttr != .title && selectedAttr != .calendar),
           mode != .viewable  {
            // public인 경우 그룹은 deactivate 하면 안됨
            if !((mode == .newPublic || mode == .editablePublic) && selectedAttr == .group) {
                delegate?.deactivate(attr: selectedAttr)
            }
            selectedAttr = .title
        }
        delegate?.move(from: viewingAttr, to: selectedAttr)
        viewingAttr = selectedAttr
    }
    
    
}

protocol TodoDetailIcnViewDelegate: AnyObject {
    func deactivate(attr: TodoDetailAttribute)
    func move(from: TodoDetailAttribute, to: TodoDetailAttribute)
}
