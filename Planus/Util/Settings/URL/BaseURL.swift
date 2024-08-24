//
//  BaseURL.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/05/04.
//

import Foundation

struct BaseURL {
//    static let main: String = {
//        return (UserDefaults.standard.object(forKey: "serverTestURL") as? String) ?? "none"
//    }()
//    
    static func main() -> String {
        return (UserDefaults.standard.object(forKey: "serverTestURL") as? String) ?? "none"

    }
}
