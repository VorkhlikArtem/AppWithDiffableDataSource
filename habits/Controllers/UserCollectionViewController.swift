//
//  UserCollectionViewController.swift
//  habits
//
//  Created by Артём on 25.04.2022.
//

import UIKit

private let reuseIdentifier = "User"

class UserCollectionViewController: UICollectionViewController {
    
    var usersRequestTask: Task<Void, Never>? = nil
    deinit { usersRequestTask?.cancel()}
    
    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>

    enum ViewModel {
       typealias Section = Int
        
        struct Item: Hashable{
            let user: User
            let isFollowed: Bool
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(user)
            }
            static func == (lhs: Item, rhs: Item) -> Bool {
                return lhs.user == rhs.user
            }
            
        }
    }
    
    struct Model{
        var usersByID = [String: User]()
        var followedUsers: [User] {
           return Array(usersByID.filter{Settings.shared.followedUserIDs.contains($0.key)}.values)
        }
    }
    
    var dataSource: DataSourceType!
    var model = Model()

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        update()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }
    
    func createDataSource()->DataSourceType{
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! UICollectionViewListCell
            var content = cell.defaultContentConfiguration()
            content.text = item.user.name
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 11, leading: 8, bottom: 11, trailing: 8)
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            return cell
        }
        return dataSource
    }
    
    func createLayout()-> UICollectionViewCompositionalLayout{
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalHeight(1), heightDimension: .fractionalHeight(1)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalWidth(0.45)),
            subitem: item,
            count: 2)
        group.interItemSpacing = .fixed(20)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)

        return UICollectionViewCompositionalLayout(section: section)
    }
    
    func update() {
        usersRequestTask?.cancel()
        usersRequestTask = Task {
            if let users = try? await UserRequest().send() {
                model.usersByID = users
            } else {
                self.model.usersByID = [:]
            }
            updateCollectionView()
            usersRequestTask = nil
        }
    }
    
    func updateCollectionView() {
        let users = model.usersByID.values.sorted().reduce(into: [ViewModel.Item]()) { partialResult, user in
            partialResult.append(ViewModel.Item(user: user, isFollowed: model.followedUsers.contains(user)))
        }
        
        let itemsBySection = [0: users]
        
        dataSource.applySnapshotUsing(sectionIDs: [0], itemsBySection: itemsBySection)
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            guard let item = self.dataSource.itemIdentifier(for: indexPath) else {return nil}
            
            let favoriteToggle = UIAction(title:
                                            item.isFollowed ? "Unfollowed" : "Followed") { action in
                Settings.shared.toggleFollowed(user: item.user)
                self.updateCollectionView()
            }
            return UIMenu(title: "", image: nil, identifier: nil, options: [], children: [favoriteToggle])
        }
        return config
    }
    
    
    @IBSegueAction func showUserDetail(_ coder: NSCoder, sender: Any?) -> UserDetailViewController? {
        guard let cell = sender as? UICollectionViewCell,
              let indexPath = collectionView.indexPath(for: cell),
              let item = dataSource.itemIdentifier(for: indexPath) else {return nil}
        return UserDetailViewController(coder: coder, user: item.user)
    }
    
 
}
