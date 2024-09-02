//
//  Task.swift
//  ToDoListApp
//
//  Created by Rolva Mashale on 2024/09/02.
//

import Foundation
import RxDataSources

struct Task {
    var date: String
    var items: [Todo]
}

extension Task: SectionModelType {
    typealias Item = Todo
    
    init(original: Task, items: [Item]) {
        self = original
        self.items = items
    }
}
