//
//  HabitCollectionViewController.swift
//  habits
//
//  Created by Артём on 25.04.2022.
//

import UIKit

private let reuseIdentifier = "Habit"

class HabitCollectionViewController: UICollectionViewController {
    
    var habitsRequestTask: Task<Void, Never>? = nil
    deinit { habitsRequestTask?.cancel()}
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>

    enum ViewModel {
        enum Section: Hashable, Comparable{
            case favorites
            case category(_ category: Category)
            
            static func < (lhs: Section, rhs: Section) -> Bool {
                switch (lhs, rhs) {
                case (.category(let l), .category(let r)):
                    return l.name < r.name
                case (.favorites, _):
                    return true
                case (_, .favorites):
                    return false
                }
            }
        }
        typealias Item = Habit
    }
    
    struct Model{
        var habitsByName = [String: Habit]()
        var favoriteHabits: [Habit] {return Settings.shared.favoriteHabits }
    }
    
    var dataSource: DataSourceType!
    var model = Model()
    
    enum SectionHeader: String{
        case kind = "SectionHeader"
        case reuse = "HeaderView"
        var identifier: String{rawValue}
    }
    
  
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier)
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }
    
    func createDataSource()->DataSourceType{
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! UICollectionViewListCell
            var content = cell.defaultContentConfiguration()
            content.text = item.name
            cell.contentConfiguration = content
            return cell
        }
        
        dataSource.supplementaryViewProvider = {collectionView, kind, indexPath in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier, for: indexPath) as! NamedSectionHeaderView
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case .favorites:
                header.nameLabel.text = "Favorites"
            case .category(let category):
                header.nameLabel.text = category.name
            }
            return header
        }
        return dataSource
    }
    
    func createLayout()-> UICollectionViewCompositionalLayout{
     
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(36)),
            elementKind: SectionHeader.kind.identifier,
            alignment: .top)
        
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(44)),
            subitem: item,
            count: 1)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        section.boundarySupplementaryItems = [header]
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    func update() {
        habitsRequestTask?.cancel()
        habitsRequestTask = Task {
            if let habit = try? await HabitRequest().send() {
                model.habitsByName = habit
            } else {
                self.model.habitsByName = [:]
            }
            updateCollectionView()
            habitsRequestTask = nil
        }
    }
    
    func updateCollectionView() {
        var itemsBySection = model.habitsByName.values.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partialResult, habit in
            let item = habit
            
            let section: ViewModel.Section
            if model.favoriteHabits.contains(habit) {
                section = .favorites
            } else {
                section = .category(habit.category)
            }
            partialResult[section, default: []].append(item)
        }
        
        itemsBySection = itemsBySection.mapValues{$0.sorted()}
        
        let sectionIDs = itemsBySection.keys.sorted()
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let item = self.dataSource.itemIdentifier(for: indexPath)!
            
            let favoriteToggle = UIAction(title:
                                self.model.favoriteHabits.contains(item) ? "Unfavorite" : "Favorite") { action in
                Settings.shared.toggleFavorite(item)
                self.updateCollectionView()
            }
            return UIMenu(title: "", image: nil, identifier: nil, options: [], children: [favoriteToggle])
        }
        return config
    }
    
    
    @IBSegueAction func showHabitDetail(_ coder: NSCoder, sender: Any?) -> HabitDetailViewController? {
        
        guard let cell = sender as? UICollectionViewCell,
              let indexPath = collectionView.indexPath(for: cell),
              let item = dataSource.itemIdentifier(for: indexPath) else {return nil}
              
        return HabitDetailViewController(coder: coder, habit: item)
    }
    
}

