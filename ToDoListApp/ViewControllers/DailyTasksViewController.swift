//
//  DailyTasksViewController.swift
//  ToDoListApp
//
//  Created by Rolva Mashale on 2024/09/02.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import RxDataSources

protocol SendDataDelegate {
    func sendData(oldTask: Todo?, newTask: Todo, indexPath: IndexPath?)
    func sendData(scheduledTasks: [String : [Todo]], newDate: Date)
}

class DailyTasksViewController: UIViewController {
    
    @IBOutlet weak var tblTodo: UITableView!
    @IBOutlet weak var btnAdd: UIButton!
    @IBOutlet weak var btnEditTable: UIBarButtonItem!
    
    private var todoSections: BehaviorRelay<[Task]> = BehaviorRelay(value: [])
    private var dataSource: RxTableViewSectionedReloadDataSource<Task>!
    var viewModel = TodoListViewModel()
    var disposeBag = DisposeBag()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Cell
        let nibName = UINib(nibName: TodoTableViewCell.nibName, bundle: nil)
        tblTodo.register(nibName, forCellReuseIdentifier: TodoTableViewCell.identifier)
        tblTodo.rowHeight = UITableView.automaticDimension
        
        // UI Binding
        setupBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tblTodo.reloadData()
    }
    
    // MARK: - UI Binding
    
    func setupBindings() {
        dataSource = RxTableViewSectionedReloadDataSource<Task> { dataSource, tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: TodoTableViewCell.identifier, for: indexPath) as! TodoTableViewCell
            
            // cell
            cell.bind(task: item)
            
            cell.btnCheckbox.indexPath = indexPath
            cell.btnCheckbox.addTarget(self, action: #selector(self.checkboxSelection(_:)), for: .touchUpInside)
            return cell
        }
        
        Observable.zip(tblTodo.rx.modelSelected(Todo.self), tblTodo.rx.itemSelected)
            .bind { [weak self] (task, indexPath) in
                guard let addTaskVC = self?.storyboard?.instantiateViewController(identifier: AddTaskViewController.storyboardID) as? AddTaskViewController else { return }
                addTaskVC.editTask = task
                addTaskVC.indexPath = indexPath
                addTaskVC.delegate = self
                addTaskVC.currentDate = self?.viewModel.selectedDate.value
                
                self?.navigationController?.pushViewController(addTaskVC, animated: true)
            }
            .disposed(by: disposeBag)
        
        tblTodo.rx.itemDeleted
            .bind { indexPath in
                if indexPath.section == 0 {
                    _ = self.viewModel.remove(section: .scheduled, row: indexPath.row, date: nil)
                } else {
                    _ = self.viewModel.remove(section: .anytime, row: indexPath.row, date: nil)
                }
            }
            .disposed(by: disposeBag)
        
        tblTodo.rx.itemMoved
            .bind { srcIndexPath, dstIndexPath in
                var movedTask: Todo?
                
                if srcIndexPath.section == 0 {
                    movedTask = self.viewModel.remove(section: .scheduled, row: srcIndexPath.row, date: nil)
                } else {
                    movedTask = self.viewModel.remove(section: .anytime, row: srcIndexPath.row, date: nil)
                }
                
                if let movedTask = movedTask {
                    if dstIndexPath.section == 0 {
                        self.viewModel.insert(task: movedTask, section: .scheduled, row: dstIndexPath.row, date: nil)
                    } else {
                        self.viewModel.insert(task: movedTask, section: .anytime, row: dstIndexPath.row, date: nil)
                    }
                }
            }
            .disposed(by: disposeBag)
        
        dataSource.titleForHeaderInSection = { ds, index in
            let date = ds.sectionModels[index].date
            return date.isEmpty ? Section.anytime.rawValue : "\(Section.scheduled.rawValue) \(date)"
        }
        
        todoSections.asDriver()
            .drive(tblTodo.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        Observable.combineLatest(viewModel.todoScheduled, viewModel.todoAnytime, viewModel.selectedDate)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] scheduled, anytime, date in
                let dateString = date.toString()
                self?.todoSections.accept([Task(date: dateString, items: scheduled[dateString] ?? []),
                                           Task(date: "", items: anytime)])
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Actions
    
    @IBAction func addTaskButtonPressed(_ sender: UIButton) {
        // Create Task
        guard let addTaskVC = self.storyboard?.instantiateViewController(identifier: AddTaskViewController.storyboardID) as? AddTaskViewController else { return }
        addTaskVC.delegate = self
        addTaskVC.currentDate = viewModel.selectedDate.value
        
        self.navigationController?.pushViewController(addTaskVC, animated: true)
    }
    
    @IBAction func editTableButtonPressed(_ sender: UIBarButtonItem) {
        if tblTodo.isEditing {
            btnEditTable.title = "Edit"
            tblTodo.setEditing(false, animated: true)
        } else {
            btnEditTable.title = "Done"
            tblTodo.setEditing(true, animated: true)
        }
    }
    
    @IBAction func calendarButtonPressed(_ sender: UIBarButtonItem) {
        // Calendar 화면 표시
        guard let calendarVC = self.storyboard?.instantiateViewController(identifier: CalendarViewController.storyboardID) as? CalendarViewController else { return }
        calendarVC.delegate = self
        calendarVC.todoScheduled = viewModel.todoScheduled.value
        calendarVC.selectedDate = viewModel.selectedDate.value
        
        let navController = UINavigationController(rootViewController: calendarVC)
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true, completion: nil)
    }
    
    @objc func checkboxSelection(_ sender: CheckUIButton) {
        guard let indexPath = sender.indexPath else { return }
        
        if indexPath.section == 0 {
            viewModel.changeComplete(section: .scheduled, row: indexPath.row)
        } else {
            viewModel.changeComplete(section: .anytime, row: indexPath.row)
        }
    }
}

// MARK: - SendDataDelegate

extension DailyTasksViewController: SendDataDelegate {
    
    /* Calendar -> DailyTasks */
    func sendData(scheduledTasks: [String : [Todo]], newDate: Date) {
        if !scheduledTasks.isEmpty {
            viewModel.todoScheduled.accept(scheduledTasks)
        }
        viewModel.selectedDate.accept(newDate)
    }
    
    /* AddTask -> DailyTasks */
    func sendData(oldTask: Todo?, newTask: Todo, indexPath: IndexPath?) {
        let oldDate = oldTask?.date ?? ""
        let newDate = newTask.date ?? ""
        
        // OldTask
        if let _ = oldTask, let index = indexPath {
            if oldDate.isEmpty {    // Anytime
                _ = viewModel.remove(section: .anytime, row: index.row, date: nil)
            } else {                // Scheduled
                _ = viewModel.remove(section: .scheduled, row: index.row, date: oldTask?.date)
            }
        }
        
        // NewTask 
        if newDate.isEmpty {    // Anytime
            viewModel.insert(task: newTask, section: .anytime, row: indexPath?.row, date: nil)
        } else {                // Scheduled
            viewModel.insert(task: newTask, section: .scheduled, row: indexPath?.row, date: newDate)
        }
    }
}
