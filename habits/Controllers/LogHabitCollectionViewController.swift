//
//  LogHabitCollectionViewController.swift
//  habits
//
//  Created by Артём on 25.04.2022.
//

import UIKit

private let reuseIdentifier = "Habit"

class LogHabitCollectionViewController: HabitCollectionViewController {
    enum SectionHeader: String{
        case kind = "SectionHeader"
        case reuse = "HeaderView"
        var identifier: String{rawValue}
    }

    override func viewDidLoad() {
        super.viewDidLoad()

  
    }
    override func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, environment in
            if sectionIndex == 0 && self.model.favoriteHabits.count > 0 {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.45), heightDimension: .fractionalHeight(1)))
                item.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
                
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(100)),
                    subitem: item,
                    count: 2)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
               
                return section
            } else {
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(36)),
                    elementKind: SectionHeader.kind.identifier,
                    alignment: .top)
                header.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: nil, trailing: nil, bottom: .fixed(40))
                header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
            
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(50)),
                    subitem: item,
                    count: 2)
                group.interItemSpacing = .fixed(8)
                group.contentInsets = .init(top: 0, leading: 10, bottom: 0, trailing: 10)
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
                section.interGroupSpacing = 10
                section.boundarySupplementaryItems = [header]
                
                return section
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {return}
        let loggedHabit = LoggedHabit(userId: Settings.shared.currentUser.name, habitName: item.name, timestamp: Date())
        Task {
           try? await LogHabitRequest(loggedHabit: loggedHabit).send()
        }
    }

   
}
