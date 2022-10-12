//
//  HomeCollectionViewController.swift
//  habits
//
//  Created by Артём on 25.04.2022.
//

import UIKit

private let leaderboardHabitIdentifier = "LeaderboardHabit"
private let followedUserIdentifier = "FollowedUser"

enum SupplementaryItemType{
    case collectionSupplymentaryView
    case layoutDecorationView
}
protocol SupplementaryItem{
    associatedtype ViewClass: UICollectionReusableView
    var itemType: SupplementaryItemType{get}
    var reuseIdentifier: String{get}
    var viewKind: String{get}
    var viewClass: ViewClass.Type{get}
}
extension SupplementaryItem {
    func register(on collectionView: UICollectionView) {
        switch itemType {
        case .collectionSupplymentaryView:
            collectionView.register(viewClass.self, forSupplementaryViewOfKind: viewKind, withReuseIdentifier: reuseIdentifier)
        case .layoutDecorationView:
            collectionView.collectionViewLayout.register(viewClass.self, forDecorationViewOfKind: viewKind)
        }
    }
}
enum SupplementaryView: String, CaseIterable, SupplementaryItem{
    case leaderboardSectionHeader
    case leaderboardBackground
    case followedUserSectionHeader
    
    var reuseIdentifier: String{
        return rawValue
    }
    var viewKind: String{
        return rawValue
    }
    var viewClass: UICollectionReusableView.Type{
        switch self {
        case .leaderboardBackground:
            return SectionBackgroundView.self
        default:
            return NamedSectionHeaderView.self
        }
    }
    var itemType: SupplementaryItemType{
        switch self {
        case .leaderboardBackground:
            return .layoutDecorationView
        default:
            return .collectionSupplymentaryView
        }
    }
}
class SectionBackgroundView: UICollectionReusableView {
    override func didMoveToSuperview() {
        backgroundColor = .systemGray6
    }
}

class HomeCollectionViewController: UICollectionViewController {
    var habitsRequestTask: Task<Void, Never>? = nil
    var usersRequestTask: Task<Void, Never>? = nil
    var combinedStatsRequestTask: Task<Void, Never>? = nil
    deinit {
        habitsRequestTask?.cancel()
        usersRequestTask?.cancel()
        combinedStatsRequestTask?.cancel()
    }
    
    var updateTimer: Timer?
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>

    enum ViewModel {
        enum Section: Hashable {
            case leaderboard
            case followedUsers
        }
        enum Item : Hashable {
            case leaderboarHabit(name: String, leadingUserRanking: String?, secondaryUserRanking: String?)
            case followedUser(_ user: User, message: String)
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .leaderboarHabit(name: let name, _, _):
                    hasher.combine(name)
                case .followedUser(let User, _):
                    hasher.combine(User)
                }
            }
            static func == (lhs: Item, rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.leaderboarHabit(name: let lName, _, _), .leaderboarHabit(name: let rName, _, _)):
                    return lName == rName
                case (.followedUser(let lUser, _), .followedUser(let rUser, _)):
                    return lUser == rUser
                default: return false
                }
            }
        }
    }
    
    struct Model{
        var habitStatistics = [HabitStatistics]()
        var userStatistics = [UserStatistics]()
        
        var habitsByName = [String: Habit]()
        var favoriteHabits: [Habit] {return Settings.shared.favoriteHabits }
        
        var usersByID = [String: User]()
        var followedUsers: [User] {
           return Array(usersByID.filter{Settings.shared.followedUserIDs.contains($0.key)}.values)
        }
        
        var currentUser: User {
            Settings.shared.currentUser
        }
        
        var users: [User] {
            usersByID.values.map{$0}
        }
        
        var habits: [Habit]{
            habitsByName.values.map{$0}
        }
        var nonFavoriteHabits: [Habit]{
            habits.filter{!favoriteHabits.contains($0)}
        }
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
        habitsRequestTask = Task {
            if let habits = try? await HabitRequest().send() {
                model.habitsByName = habits
            }
            updateCollectionView()
            habitsRequestTask = nil
        }
        usersRequestTask = Task {
            if let users = try? await UserRequest().send() {
                model.usersByID = users
            }
            updateCollectionView()
            usersRequestTask = nil
        }
        for supplementaryView in SupplementaryView.allCases {
            supplementaryView.register(on: collectionView)
        }
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
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
    
    func createDataSource()->DataSourceType{
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, item  in
            switch item {
            case .leaderboarHabit(name: let name, leadingUserRanking: let leadingUserRanking, secondaryUserRanking: let secondaryUserRanking):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: leaderboardHabitIdentifier, for: indexPath) as! LeaderboardHabitCollectionViewCell
                cell.habitNameLabel.text = name
                cell.leaderLabel.text = leadingUserRanking
                cell.secondaryLabel.text = secondaryUserRanking
                return cell
            case .followedUser(let user, message: let message):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: followedUserIdentifier, for: indexPath) as! FollowedUserCollectionViewCell
                cell.primaryTextLabel.text = user.name
                cell.secondaryTextLabel.text = message
                return cell
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            guard let elementKind = SupplementaryView(rawValue: kind) else {return nil}
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind.viewKind, withReuseIdentifier: elementKind.reuseIdentifier, for: indexPath)
            switch elementKind {
            case .leaderboardSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Leaderboard"
                header.nameLabel.font = .preferredFont(forTextStyle: .largeTitle)
                header.alignLabelToTop()
                return header
            case .followedUserSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Following"
                header.nameLabel.font = .preferredFont(forTextStyle: .title2)
                header.alignLabelToYCenter()
                return header
            default: return nil
            }
        }

        return dataSource
    }
    
    
    func createLayout()-> UICollectionViewCompositionalLayout{
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .leaderboard:
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3)))
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(0.75),
                        heightDimension: .absolute(0.75)),
                    subitem: item,
                    count: 3)
                group.interItemSpacing = .fixed(10)
                
                let section = NSCollectionLayoutSection(group: group)
                
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(80)),
                    elementKind: SupplementaryView.leaderboardSectionHeader.viewKind,
                    alignment: .top)
                let background = NSCollectionLayoutDecorationItem.background(elementKind: SupplementaryView.leaderboardBackground.viewKind)
                section.boundarySupplementaryItems = [header]
                section.decorationItems = [background]
                section.supplementariesFollowContentInsets = false
                
                section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 20, trailing: 20)
                section.interGroupSpacing = 20
                section.orthogonalScrollingBehavior = .continuous
                return section
            case .followedUsers:
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(60)),
                    elementKind: SupplementaryView.followedUserSectionHeader.viewKind,
                    alignment: .top)
                
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100)))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(100)),
                    subitem: item,
                    count: 1)
                         
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
        return layout
    
    }
    
    func update(){
        combinedStatsRequestTask?.cancel()
        combinedStatsRequestTask = Task{
            if let combinedStats = try? await CombinedStatisticsRequest().send() {
                model.userStatistics = combinedStats.userStatictics
                model.habitStatistics = combinedStats.habitStatistics
            } else {
                model.userStatistics = []
                model.habitStatistics = []
            }
            self.updateCollectionView()
            combinedStatsRequestTask = nil
        }
    }

    func updateCollectionView(){
        var sectionIDs = [ViewModel.Section]()
        
        let leaderboardItems = model.habitStatistics.filter { statistic in
            return model.favoriteHabits.contains{ $0.name == statistic.habit.name}
        }
            .sorted{ $0.habit.name < $1.habit.name}
            .reduce(into: [ViewModel.Item]()) { partial, statistic in
                // Rank the user counts from highest to lowest
                let rankedUserCounts = statistic.userCount.sorted { $0.count > $1.count}
                    // Find the index of the current user's count, keeping in mind that it wont exist if the user hasn't logged that habit yet
                let myCountIndex = rankedUserCounts.firstIndex{ $0.user.id == self.model.currentUser.id}
                
                func userRankingString(from userCount: UserCount) -> String {
                    var name = userCount.user.name
                    var ranking = ""
                    if userCount.user.id == self.model.currentUser.id {
                        name = "You"
                        ranking = "\(ordinalString(from: myCountIndex!))"
                    }
                    return "\(name) \(userCount.count)" + ranking
                }
                
                var leadingRanking: String?
                var secondaryRanking: String?
                
                    // Examine the number of user counts for the statistic:
                switch rankedUserCounts.count {
                case 0:
                       // If 0, set the leader label to "Nobody Yet!" and leave the secondary label `nil`
                    leadingRanking = "Nobody Yet!"
                case 1:
                       // If 1, set the leader label to the only user and count
                    let onlyCount = rankedUserCounts.first!
                    leadingRanking = userRankingString(from: onlyCount)
                default:
                       // Otherwise, do the following:
                           // Set the leader label to the user count at index 0
                    leadingRanking = userRankingString(from: rankedUserCounts[0])
                           // Check whether the index of the current user's count exists and is not 0
                    if let myCountIndex = myCountIndex, myCountIndex != rankedUserCounts.startIndex {
                               // If true, the user's count and ranking should be displayed in the secondary label
                        secondaryRanking = userRankingString(from: rankedUserCounts[myCountIndex])
                               // If false, the second-place user count should be displayed
                    } else {
                        secondaryRanking = userRankingString(from: rankedUserCounts[1])
                    }
                }
                let leaderboardItem = ViewModel.Item.leaderboarHabit(name: statistic.habit.name, leadingUserRanking: leadingRanking, secondaryUserRanking: secondaryRanking)
                partial.append(leaderboardItem)
            }
        
        
        sectionIDs.append(.leaderboard)
        var itemsBySection = [ViewModel.Section.leaderboard: leaderboardItems]
        
        
        var followedUserItems = [ViewModel.Item]()
        func loggedHabitNames(for user: User) -> Set<String> {
            var names = [String]()
            if let stats = model.userStatistics.first(where: {$0.user == user}) {
                names = stats.habitCount.map { $0.habit.name}
            }
            return Set(names)
        }
        // Get the current user's logged habits and extract the favorites
        let currentUserLoggedHabits = loggedHabitNames(for: model.currentUser)
        let favoriteLoggedHabits = Set(model.favoriteHabits.map {$0.name}).intersection(currentUserLoggedHabits)
        // Loop through all the followed users
        for followedUser in model.followedUsers.sorted(by: {$0.name < $1.name}) {
            let message : String
            let followedUserLoggedHabit = loggedHabitNames(for: followedUser)
            
            // If the users have a habit in common:
            let commonLoggedHabit = followedUserLoggedHabit.intersection(currentUserLoggedHabits)
            if commonLoggedHabit.count > 0 {
            // Pick the habit to focus on
                let habitName: String
                let commonFavoriteLoggedHabits = favoriteLoggedHabits.intersection(commonLoggedHabit)
                if commonFavoriteLoggedHabits.count > 0 {
                    habitName = commonFavoriteLoggedHabits.sorted().first!
                } else {
                    habitName = commonLoggedHabit.sorted().first!
                }
                
                // Get the full statistics (all the user counts) for that habit
                let habitStats = model.habitStatistics.first(where: {$0.habit.name == habitName})!
                
                // Get the ranking for each user
                let rankedUserCount = habitStats.userCount.sorted(by: {$0.count > $1.count})
                let currentUserRanking = rankedUserCount.firstIndex(where: {$0.user == model.currentUser})!
                let followedUserRanking = rankedUserCount.firstIndex(where: {$0.user == followedUser})!
                
                // Construct the message depending on who's leading
                if currentUserRanking < followedUserRanking {
                    message = "Currently #\(ordinalString(from: followedUserRanking)), behind you (#\(ordinalString(from: currentUserRanking))) in \(habitName).\nSend them a friendly reminder!"
                } else if currentUserRanking > followedUserRanking {
                    message = "Currently #\(ordinalString(from: followedUserRanking)), ahead of you (#\(ordinalString(from: currentUserRanking))) in \(habitName).\nYou might catch up with a little extra effort!"
                } else {
                    message = "You're tied at \(ordinalString(from: followedUserRanking)) in \(habitName)! Now's your chance to pull ahead."
                } 
            } else if followedUserLoggedHabit.count > 0 {
                // Get an arbitrary habit name
                let habitName = followedUserLoggedHabit.sorted().first!
                
                // Get the full statistics (all the user counts) for that habit
                let habitStats = model.habitStatistics.first {$0.habit.name == habitName}!
                
                // Get the user's ranking for that habit
                let rankedUserCount = habitStats.userCount.sorted(by: {$0.count > $1.count})
                let followedUserRanking = rankedUserCount.firstIndex(where: {$0.user == followedUser})!
                message = "Currently #\(ordinalString(from: followedUserRanking)), in \(habitName).\nMaybe you should give this habit a look."
                // Otherwise, this user hasn't done anything
            } else {
                 message = "This user doesn't seem to have done much yet. Check in to see if they need any help getting started."
            }
            followedUserItems.append(.followedUser(followedUser, message: message))
        
        }
        sectionIDs.append(.followedUsers)
        itemsBySection[.followedUsers] = followedUserItems
        
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    static let formatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()
    func ordinalString(from number: Int) -> String {
        Self.formatter.string(from: NSNumber(integerLiteral: number + 1))!
    }

}
