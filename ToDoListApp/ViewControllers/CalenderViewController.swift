//
//  CalenderViewController.swift
//  ToDoListApp
//
//  Created by Rolva Mashale on 2024/09/02.
//

import Foundation
import UIKit
import FSCalendar
import RxSwift
import RxCocoa

class CalendarViewController: UIViewController, UITableViewDataSource {
    
    @IBOutlet weak var calendar: FSCalendar!
    @IBOutlet weak var tblTasks: UITableView!
    @IBOutlet weak var btnScope: UIBarButtonItem!
    @IBOutlet weak var calendarHeightConstraint: NSLayoutConstraint!
    
    // MARK: - Instance Properties
    
    static let storyboardID = "calendarTask"
    
    var delegate: SendDataDelegate?
    var todoScheduled: [String : [Todo]] = [:]
    var selectedDate = Date()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        let nibName = UINib(nibName: TodoTableViewCell.nibName, bundle: nil)
        tblTasks.register(nibName, forCellReuseIdentifier: TodoTableViewCell.identifier)
        tblTasks.rowHeight = UITableView.automaticDimension
        
        calendar.select(selectedDate)
        
        calendarHeightConstraint.constant = self.view.bounds.height / 2
        // Title
        calendar.calendarWeekdayView.weekdayLabels[0].textColor = UIColor(red: 255/255, green: 126/255, blue: 121/255, alpha: 1.0)
        calendar.calendarWeekdayView.weekdayLabels[6].textColor = calendar.calendarWeekdayView.weekdayLabels[0].textColor
    }
    
    // MARK: - Tableview DataSource
    
    /* cell*/
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todoScheduled[selectedDate.toString()]?.count ?? 0
    }
    
    /* section */
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return selectedDate.toString()
    }
    
    /* cell */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as! TodoTableViewCell
        guard let task = todoScheduled[selectedDate.toString()]?[indexPath.row] else { return cell }
        
        // cell
        cell.bind(task: task)
        
        cell.btnCheckbox.indexPath = indexPath
        cell.btnCheckbox.addTarget(self, action: #selector(checkboxSelection(_:)), for: .touchUpInside)
        
        return cell
    }
    
    // MARK: - Actions
    
    @objc func checkboxSelection(_ sender: CheckUIButton) {
        guard let indexPath = sender.indexPath else { return }
        
        // Complete
        todoScheduled[selectedDate.toString()]?[indexPath.row].isCompleted.toggle()
        
        tblTasks.reloadData()
        calendar.reloadData()
    }
    
    /* Done */
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        // DailyTasks
        delegate?.sendData(scheduledTasks: todoScheduled, newDate: selectedDate)
        dismiss(animated: true, completion: nil)
    }
    
    /* Week/Month Scope */
    @IBAction func changeScopeButtonPressed(_ sender: UIBarButtonItem) {
        if calendar.scope == .month {
            calendar.scope = .week
            btnScope.title = "Month"
        } else {
            calendar.scope = .month
            btnScope.title = "Week"
        }
    }
}

// MARK: - Calendar Delegate

extension CalendarViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        selectedDate = date
        tblTasks.reloadData()
    }
    
    /* Week/Month Scope */
    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        calendarHeightConstraint.constant = bounds.height
        self.view.layoutIfNeeded()
    }
    
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        if let tasks = todoScheduled[date.toString()], tasks.count > 0 { return 1 }
        return 0
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        if let tasks = todoScheduled[date.toString()] {

            if tasks.filter({ $0.isCompleted == false }).count > 0 { return [UIColor.systemRed] }
            return [UIColor.systemGray2]
        }
        return nil
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventSelectionColorsFor date: Date) -> [UIColor]? {
        if let tasks = todoScheduled[date.toString()] {
            if tasks.filter({ $0.isCompleted == false }).count > 0 { return [UIColor.systemRed] }
            return [UIColor.systemGray2]
        }
        return nil
    }
}
