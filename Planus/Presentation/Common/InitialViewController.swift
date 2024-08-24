//
//  InitialViewController.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/20.
//

import UIKit
import SnapKit

class InitialViewController: UIViewController {
    
    weak var delegate: InitDelegate?
    
    let key = "serverTestURL"

    var exLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    var urlField: UITextField = {
        let textField = UITextField()
        textField.layer.borderColor = UIColor.blue.cgColor
        textField.layer.borderWidth = 1
        return textField
    }()
    
    var exButton: UIButton = {
        let exButton = UIButton(type: .roundedRect)
        exButton.setTitle("원래꺼 사용", for: .normal)
        exButton.setTitleColor(.blue, for: .normal)
        exButton.addTarget(self, action: #selector(exTap), for: .touchUpInside)
        return exButton
    }()
    
    var newButton: UIButton = {
        let newButton = UIButton(type: .roundedRect)
        newButton.setTitle("새거 사용", for: .normal)
        newButton.setTitleColor(.blue, for: .normal)
        newButton.addTarget(self, action: #selector(newTap), for: .touchUpInside)
        return newButton
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .planusBackgroundColor
        
        
        self.view.addSubview(urlField)
        self.view.addSubview(exLabel)
        self.view.addSubview(exButton)
        self.view.addSubview(newButton)
        
        urlField.snp.makeConstraints {
            $0.top.equalToSuperview().offset(60)
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.height.equalTo(40)
        }
        
        exLabel.snp.makeConstraints {
            $0.top.equalTo(urlField.snp.bottom).offset(30)
            $0.leading.trailing.equalToSuperview().inset(30)
        }
        
        exButton.snp.makeConstraints {
            $0.top.equalTo(exLabel.snp.bottom).offset(30)
            $0.leading.trailing.equalToSuperview().inset(30)
        }
        
        newButton.snp.makeConstraints {
            $0.top.equalTo(exButton.snp.bottom).offset(30)
            $0.leading.trailing.equalToSuperview().inset(30)
        }
        
        let exURL = UserDefaults.standard.object(forKey: key)
        exLabel.text = "원래꺼: \(BaseURL.main())"
    }
    
    @objc
    func exTap(_ sender: UIButton) {
        delegate?.fin()
    }
    
    @objc
    func newTap(_ sender: UIButton) {
        UserDefaults.standard.set(urlField.text, forKey: key)
        delegate?.fin()
    }
}

protocol InitDelegate: AnyObject {
    func fin()
}


