//
//  Extension.swift
//  GPS Diary
//
//  Created by Robert Spang on 28.10.21.
//

import Foundation


extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: [Iterator.Element: Bool] = [:]
        return self.filter { seen.updateValue(true, forKey: $0) == nil }
    }
}
