//
//  UserDetailViewController.swift
//  habits
//
//  Created by Артём on 25.04.2022.
//

import UIKit

private let reuseIdentifier = "HabitCount"

class UserDetailViewController: UIViewController {
    
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var user: User!
    var updateTimer: Timer?
    
    var userStatsRequestTask: Task<Void, Never>? = nil
    var habitLeadStatisticsRequestTask: Task<Void, Never>? = nil
    var imageRequestTask: Task<Void, Never>? = nil
    deinit {
        userStatsRequestTask?.cancel()
        habitLeadStatisticsRequestTask?.cancel()
        imageRequestTask?.cancel()
    }
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case leading
            case category(_ category: Category)
            
            static func < (lhs: UserDetailViewController.ViewModel.Section, rhs: UserDetailViewController.ViewModel.Section) -> Bool {
                switch (lhs, rhs){
                case (.leading, _): return true
                case (.category, .leading): return false
                case (.category(let category1), .category(let category2)):
                    return category1.name > category2.name
                }
            }
        }
        typealias Item = HabitCount
    }
    
    struct Model{
        var userStats: UserStatistics?
        var leadingStats: UserStatistics?
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

        userNameLabel.text = user.name
        bioLabel.text = user.bio
        
        imageRequestTask = Task {
            if let image = try? await ImageRequest(imageID: user.id).send() {
                self.profileImageView.image = image
            }
            imageRequestTask = nil
        }
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        update()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.update()
        })
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    init?(coder: NSCoder, user: User) {
        self.user = user
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func createDataSource()->DataSourceType{
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, habitStat in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! UICollectionViewListCell
            var content = UIListContentConfiguration.subtitleCell()
            content.text = habitStat.habit.name
            content.secondaryText = "\(habitStat.count)"
            content.prefersSideBySideTextAndSecondaryText = true
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cell.contentConfiguration = content
            return cell
        }
        
        dataSource.supplementaryViewProvider = {collectionView, kind, indexPath in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier, for: indexPath) as! NamedSectionHeaderView
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case .leading:
                header.nameLabel.text = "Leading"
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
                heightDimension: .absolute(44)),
            elementKind: SectionHeader.kind.identifier,
            alignment: .top)
        header.pinToVisibleBounds = true
        
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(44)),
            subitem: item,
            count: 1)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(section: section)
    }
    
    
    func update() {
        userStatsRequestTask?.cancel()
        userStatsRequestTask = Task {
            if let userStats = try? await UserStatisticsRequest(userIDs: [user.id]).send(),
               userStats.count > 0 {
                self.model.userStats = userStats[0]
                
            } else {
                self.model.userStats = nil
            }
            updateCollectionView()
            userStatsRequestTask = nil
        }
        
        habitLeadStatisticsRequestTask?.cancel()
        habitLeadStatisticsRequestTask = Task {
            if let userStats = try? await HabitLeadStatisticsRequest(userID: user.id).send()  {
                self.model.leadingStats = userStats
            } else {
                self.model.leadingStats = nil
            }
            updateCollectionView()
            habitLeadStatisticsRequestTask = nil
        }
    }
    
    func  updateCollectionView() {
        guard let userStatistics = model.userStats,
              let leadingStatistics = model.leadingStats else {return}
        
        var itemBySection = userStatistics.habitCount.reduce(into: [ViewModel.Section : [ViewModel.Item]]()) { partialResult, habitCount in
            let section: ViewModel.Section
            if leadingStatistics.habitCount.contains(habitCount) {
                section = .leading
            } else {
                section = .category(habitCount.habit.category)
            }
            partialResult[section, default: []].append(habitCount)
        }
        itemBySection = itemBySection.mapValues{$0.sorted(by: <)}
        let sectionIDs = itemBySection.keys.sorted(by: <)
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemBySection)
    }
    
    
    
}
