//
//  FloorLayout.swift
//  MHacks
//
//  Created by Russell Ladd on 10/1/16.
//  Copyright © 2016 MHacks. All rights reserved.
//

import UIKit

protocol FloorLayoutDelegate: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, floorLayout: FloorLayout, offsetFractionForItemAt indexPath: IndexPath) -> CGFloat
    func collectionView(_ collectionView: UICollectionView, floorLayout: FloorLayout, aspectRatioForItemAt indexPath: IndexPath) -> CGFloat
}

final class FloorLayout: UICollectionViewLayout {
    
    enum SupplementaryViewKind: String {
        case Description = "Description"
    }
    
    var promotedItem: Int? = nil {
        didSet {
            invalidateLayout()
        }
    }
    
    private var delegate: FloorLayoutDelegate? {
        return collectionView?.delegate as? FloorLayoutDelegate
    }
    
    private var contentSize = CGSize.zero
    
    private var offsetFractions = [CGFloat]()
    private var aspectRatios = [CGFloat]()
    
    let sectionInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
    
    private var sectionSize: CGSize {
        return CGSize(width: contentSize.width - sectionInsets.left - sectionInsets.left,
                      height: contentSize.height - sectionInsets.top - sectionInsets.bottom)
    }
    
    private var verticalCompressionFactor: CGFloat = 1.0
    
    override func prepare() {
        super.prepare()
        
        guard  let collectionView = collectionView, let delegate = delegate else {
            return
        }
        
        contentSize = UIEdgeInsetsInsetRect(collectionView.bounds, collectionView.contentInset).size
        
        let numberOfFloors = collectionView.numberOfItems(inSection: 0)
        
        offsetFractions = (0..<numberOfFloors).map { item in
            return delegate.collectionView(collectionView, floorLayout: self, offsetFractionForItemAt: [0, item])
        }
        
        aspectRatios = (0..<numberOfFloors).map { item in
            return delegate.collectionView(collectionView, floorLayout: self, aspectRatioForItemAt: [0, item])
        }
        
        if let lastFraction = offsetFractions.last, let lastRatio = aspectRatios.last {
            
            let lastTop = sectionSize.height * lastFraction
            
            let maxHeight = lastTop + sectionSize.width / lastRatio
            
            let overshoot = maxHeight - sectionSize.height
            
            verticalCompressionFactor = (lastTop - overshoot) / lastTop
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        let cellAttributes: [UICollectionViewLayoutAttributes] = (0..<collectionView!.numberOfItems(inSection: 0)).map { item in
            return layoutAttributesForItem(at: [0, item])!
        }
        
        let viewAttributes: [UICollectionViewLayoutAttributes] = (0..<collectionView!.numberOfItems(inSection: 0)).map { item in
            return layoutAttributesForSupplementaryView(ofKind: SupplementaryViewKind.Description.rawValue, at: [0, item])!
        }
        
        return cellAttributes + viewAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        
        let layoutAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        
        let offsetFraction = offsetFractions[indexPath.item]
        let aspectRatio = aspectRatios[indexPath.item]
        
        layoutAttributes.frame = CGRect(x: sectionInsets.left, y: sectionInsets.top + sectionSize.height * offsetFraction * verticalCompressionFactor, width: sectionSize.width, height: sectionSize.width / aspectRatio)
        
        if let promotedItem = promotedItem {
            
            if indexPath.item != promotedItem {
                
                let delta = indexPath.item - promotedItem
                let sign = abs(delta) / delta
                let inverseDistance = collectionView!.numberOfItems(inSection: 0) - abs(delta)
                let inverseDelta = sign * inverseDistance
                
                layoutAttributes.frame.origin.y += CGFloat(inverseDelta) * 20.0
                
                layoutAttributes.alpha = 0.0
                
            } else {
                
                // Average position with the middle
                
                let originalY = layoutAttributes.frame.origin.y
                let middleY = sectionInsets.top + (sectionSize.height - sectionSize.width / aspectRatio) / 2.0
                
                layoutAttributes.frame.origin.y = (originalY + middleY) / 2.0
            }
        }
        
        // Lower rows should appear underneath higher rows
        layoutAttributes.zIndex = -indexPath.item
        
        return layoutAttributes
    }
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        
        let layoutAttributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: SupplementaryViewKind.Description.rawValue, with: indexPath)
        
        layoutAttributes.frame = layoutAttributesForItem(at: indexPath)!.frame
        layoutAttributes.frame.origin.y += layoutAttributes.frame.height + 10.0
        
        layoutAttributes.alpha = (promotedItem == indexPath.item) ? 1.0 : 0.0
        
        layoutAttributes.zIndex = -collectionView!.numberOfItems(inSection: 0) - indexPath.item
        
        return layoutAttributes
    }
}
