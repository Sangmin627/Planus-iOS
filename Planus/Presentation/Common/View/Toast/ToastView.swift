//
//  ToastView.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/15.
//

import UIKit

class ToastView: UIView {

    var contentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .planusWhite
        view.clipsToBounds = true
        return view
    }()
    
    var label: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "Pretendard-SemiBold", size: 12)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    convenience init(message: Message) {
        self.init(frame: .zero)
        self.setMessage(message: message)
    }
    
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
        
        contentView.layer.cornerRadius = contentView.frame.height/2
    }
    
    func configureView() {
        self.layer.masksToBounds = false
        self.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15).cgColor
        self.layer.shadowOpacity = 1
        self.layer.shadowOffset = CGSize(width: 0, height: 1)
        self.layer.shadowRadius = 2
        
        self.addSubview(contentView)
        contentView.addSubview(label)
    }
    
    func configureLayout() {
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        label.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.top.bottom.equalToSuperview().inset(8)
        }
    }
    
    func setMessage(message: Message) {
        self.label.text = message.text
        switch message.state {
        case .normal:
            label.textColor = .planusDeepNavy
        case .warning:
            label.textColor = .systemPink
        }
    }
}

extension UIViewController {
    func showToast(message: Message, fromBotton: CGFloat? = nil) {
        guard let naviationController = self.navigationController else { return }
        
        let toast = ToastView(message: message)
        naviationController.view.addSubview(toast)
        toast.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalTo(naviationController.view.safeAreaLayoutGuide.snp.bottom).inset(fromBotton == nil ? 100 : fromBotton!)
            $0.width.lessThanOrEqualToSuperview().inset(50)
        }
        UIView.animate(withDuration: 1, delay: 2.0, options: .curveEaseOut, animations: {
            toast.alpha = 0.0
        }, completion: { _ in
            toast.removeFromSuperview()
        })
    }
}
