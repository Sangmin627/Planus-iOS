//
//  TodoCategory+Ext.swift
//  Planus
//
//  Created by Sangmin Lee on 2023/03/25.
//

import UIKit

extension TodoCategory {
    var todoForCalendarColor: UIColor {
        switch self {
        case .blue:
            return UIColor(hex: 0x68A9DE, a: 0.3)
        case .gold:
            return UIColor(hex: 0xDDAF55, a: 0.3)
        case .pink:
            return UIColor(hex: 0xEAA1B4, a: 0.3)
        case .purple:
            return UIColor(hex: 0xB26EDB, a: 0.3)
        case .green:
            return UIColor(hex: 0x79C357, a: 0.3)
        case .navy:
            return UIColor(hex: 0x6B68D1, a: 0.3)
        case .red:
            return UIColor(hex: 0xE57D6D, a: 0.3)
        case .yello:
            return UIColor(hex: 0xF5CC5A, a: 0.3)
        case .none:
            return UIColor(hex: 0x111111, a: 0)
        }
    }
    
    var todoLeadingColor: UIColor {
        switch self {
        case .blue:
            return UIColor(hex: 0x68A9DE)
        case .gold:
            return UIColor(hex: 0xDDAF55)
        case .pink:
            return UIColor(hex: 0xEAA1B4)
        case .purple:
            return UIColor(hex: 0xB26EDB)
        case .green:
            return UIColor(hex: 0x79C357)
        case .navy:
            return UIColor(hex: 0x6B68D1)
        case .red:
            return UIColor(hex: 0xE57D6D)
        case .yello:
            return UIColor(hex: 0xF5CC5A)
        case .none:
            return UIColor(hex: 0x111111, a: 0)
        }
    }
    
    var todoThickColor: UIColor {
        switch self {
        case .blue:
            return UIColor(hex: 0x3E5C96)
        case .gold:
            return UIColor(hex: 0x8B7432)
        case .pink:
            return UIColor(hex: 0x8A4C5C)
        case .purple:
            return UIColor(hex: 0x6C4384)
        case .green:
            return UIColor(hex: 0x50813A)
        case .navy:
            return UIColor(hex: 0x3F3D7D)
        case .red:
            return UIColor(hex: 0x8F473C)
        case .yello:
            return UIColor(hex: 0xBD9525)
        case .none:
            return UIColor(hex: 0x000000)
        }
    }
}
