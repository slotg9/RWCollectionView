import UIKit

final class FlickrPhotosViewController: UICollectionViewController {
  // 1
  var largePhotoIndexPath: IndexPath? {
    didSet {
      // 2
      var indexPaths: [IndexPath] = []
      if let largePhotoIndexPath = largePhotoIndexPath {
        indexPaths.append(largePhotoIndexPath)
      }
      
      if let oldValue = oldValue {
        indexPaths.append(oldValue)
      }
      // 3
      collectionView.performBatchUpdates({
        self.collectionView.reloadItems(at: indexPaths)
      }) { _ in
        // 4
        if let largePhotoIndexPath = self.largePhotoIndexPath {
          self.collectionView.scrollToItem(at: largePhotoIndexPath,
                                           at: .centeredVertically,
                                           animated: true)
        }
      }
    }
  }
  
  var sharing: Bool = false {
    didSet {
      // 1
      collectionView.allowsMultipleSelection = sharing
      
      // 2
      collectionView.selectItem(at: nil, animated: true, scrollPosition: [])
      selectedPhotos.removeAll()
      
      guard let shareButton = self.navigationItem.rightBarButtonItems?.first else {
        return
      }
      
      // 3
      guard sharing else {
        navigationItem.setRightBarButton(shareButton, animated: true)
        return
      }
      
      // 4
      if largePhotoIndexPath != nil {
        largePhotoIndexPath = nil
      }
      
      // 5
      updateSharedPhotoCountLabel()
      
      // 6
      let sharingItem = UIBarButtonItem(customView: shareLabel)
      let items: [UIBarButtonItem] = [
        shareButton,
        sharingItem
      ]
      
      navigationItem.setRightBarButtonItems(items, animated: true)
    }
  }

  // MARK: - Properties
  private let reuseIdentifier = "FlickrCell"
  
  private let sectionInsets = UIEdgeInsets(top: 50.0,
                                           left: 20.0,
                                           bottom: 50.0,
                                           right: 20.0)
  
  private var searches: [FlickrSearchResults] = []
  private let flickr = Flickr()
  private let itemsPerRow: CGFloat = 3
  private var selectedPhotos: [FlickrPhoto] = []
  private let shareLabel = UILabel()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    collectionView.dragInteractionEnabled = true
    collectionView.dragDelegate = self
    collectionView.dropDelegate = self
  }

  
  // MARK: - IBAction
  @IBAction func share(_ sender: UIBarButtonItem) {
    guard !searches.isEmpty else {
      return
    }
    
    guard !selectedPhotos.isEmpty else {
      sharing.toggle()
      return
    }
    
    guard sharing else {
      return
    }
    
    let images: [UIImage] = selectedPhotos.compactMap { photo in
      if let thumbnail = photo.thumbnail {
        return thumbnail
      }
      
      return nil
    }
    
    guard !images.isEmpty else {
      return
    }
    
    let shareController = UIActivityViewController(
      activityItems: images,
      applicationActivities: nil)
    shareController.completionWithItemsHandler = { _, _, _, _ in
      self.sharing = false
      self.selectedPhotos.removeAll()
      self.updateSharedPhotoCountLabel()
    }
    
    shareController.popoverPresentationController?.barButtonItem = sender
    shareController.popoverPresentationController?.permittedArrowDirections = .any
    present(shareController, animated: true, completion: nil)
  }
  
}

// MARK: - Private
private extension FlickrPhotosViewController {
  func photo(for indexPath: IndexPath) -> FlickrPhoto {
    return searches[indexPath.section].searchResults[indexPath.row]
  }
  
  func removePhoto(at indexPath: IndexPath) {
    searches[indexPath.section].searchResults.remove(at: indexPath.row)
  }
  
  func insertPhoto(_ flickrPhoto: FlickrPhoto, at indexPath: IndexPath) {
    searches[indexPath.section].searchResults.insert(flickrPhoto, at: indexPath.row)
  }

  
  func performLargeImageFetch(for indexPath: IndexPath, flickrPhoto: FlickrPhoto, cell: FlickrPhotoCell) {
    cell.activityIndicator.startAnimating()
    
    flickrPhoto.loadLargeImage { [weak self] result in
      cell.activityIndicator.stopAnimating()
      
      guard let self = self else {
        return
      }
      
      switch result {
      case .results(let photo):
        if indexPath == self.largePhotoIndexPath {
          cell.imageView.image = photo.largeImage
        }
      case .error(_):
        return
      }
    }
  }

  func updateSharedPhotoCountLabel() {
    if sharing {
      shareLabel.text = "\(selectedPhotos.count) photos selected"
    } else {
      shareLabel.text = ""
    }
    
    shareLabel.textColor = themeColor
    
    UIView.animate(withDuration: 0.3) {
      self.shareLabel.sizeToFit()
    }
  }

  
}

// MARK: - Text Field Delegate
extension FlickrPhotosViewController : UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    // 1
    let activityIndicator = UIActivityIndicatorView(style: .gray)
    textField.addSubview(activityIndicator)
    activityIndicator.frame = textField.bounds
    activityIndicator.startAnimating()
    
    flickr.searchFlickr(for: textField.text!) { searchResults in
      activityIndicator.removeFromSuperview()
      
      switch searchResults {
      case .error(let error) :
        // 2
        print("Error Searching: \(error)")
      case .results(let results):
        // 3
        print("Found \(results.searchResults.count) matching \(results.searchTerm)")
        self.searches.insert(results, at: 0)
        // 4
        self.collectionView?.reloadData()
      }
    }
    
    textField.text = nil
    textField.resignFirstResponder()
    return true
  }
}

// MARK: - UICollectionViewDataSource
extension FlickrPhotosViewController {
  //1
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return searches.count
  }
  
  //2
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return searches[section].searchResults.count
  }
  
  //3
  override func collectionView(_ collectionView: UICollectionView,
                               cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: reuseIdentifier,
      for: indexPath) as? FlickrPhotoCell else {
        preconditionFailure("Invalid cell type")
    }
    
    let flickrPhoto = photo(for: indexPath)
    
    // 1
    cell.activityIndicator.stopAnimating()
    
    // 2
    guard indexPath == largePhotoIndexPath else {
      cell.imageView.image = flickrPhoto.thumbnail
      return cell
    }
    
    // 3
    guard flickrPhoto.largeImage == nil else {
      cell.imageView.image = flickrPhoto.largeImage
      return cell
    }
    
    // 4
    cell.imageView.image = flickrPhoto.thumbnail
    
    // 5
    performLargeImageFetch(for: indexPath, flickrPhoto: flickrPhoto, cell: cell)
    return cell
  }

  
  override func collectionView(_ collectionView: UICollectionView,
                               viewForSupplementaryElementOfKind kind: String,
                               at indexPath: IndexPath) -> UICollectionReusableView {
    // 1
    switch kind {
    // 2
    case UICollectionView.elementKindSectionHeader:
      // 3
      guard
        let headerView = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: "\(FlickrPhotoHeaderView.self)",
          for: indexPath) as? FlickrPhotoHeaderView
        else {
          fatalError("Invalid view type")
      }
      
      let searchTerm = searches[indexPath.section].searchTerm
      headerView.label.text = searchTerm
      return headerView
    default:
      // 4
      assert(false, "Invalid element type")
    }
  }
  
}

// MARK: - Collection View Flow Layout Delegate
extension FlickrPhotosViewController : UICollectionViewDelegateFlowLayout {
  //1
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
    //2
    if indexPath == largePhotoIndexPath {
      let flickrPhoto = photo(for: indexPath)
      var size = collectionView.bounds.size
      size.height -= (sectionInsets.top + sectionInsets.bottom)
      size.width -= (sectionInsets.left + sectionInsets.right)
      return flickrPhoto.sizeToFillWidth(of: size)
    }
    
    let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
    let availableWidth = view.frame.width - paddingSpace
    let widthPerItem = availableWidth / itemsPerRow
    
    return CGSize(width: widthPerItem, height: widthPerItem)
  }
  
  //3
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      insetForSectionAt section: Int) -> UIEdgeInsets {
    return sectionInsets
  }
  
  // 4
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return sectionInsets.left
  }
}

extension FlickrPhotosViewController {
  override func collectionView(_ collectionView: UICollectionView,
                               shouldSelectItemAt indexPath: IndexPath) -> Bool {
    guard !sharing else {
      return true
    }
    if largePhotoIndexPath == indexPath {
      largePhotoIndexPath = nil
    } else {
      largePhotoIndexPath = indexPath
    }
    
    return false
  }
  
  override func collectionView(_ collectionView: UICollectionView,
                               didSelectItemAt indexPath: IndexPath) {
    guard sharing else {
      return
    }
    
    let flickrPhoto = photo(for: indexPath)
    selectedPhotos.append(flickrPhoto)
    updateSharedPhotoCountLabel()
  }
  
  override func collectionView(_ collectionView: UICollectionView,
                               didDeselectItemAt indexPath: IndexPath) {
    guard sharing else {
      return
    }
    
    let flickrPhoto = photo(for: indexPath)
    if let index = selectedPhotos.firstIndex(of: flickrPhoto) {
      selectedPhotos.remove(at: index)
      updateSharedPhotoCountLabel()
    }
  }
  
}

// MARK: - UICollectionViewDragDelegate
extension FlickrPhotosViewController: UICollectionViewDragDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      itemsForBeginning session: UIDragSession,
                      at indexPath: IndexPath) -> [UIDragItem] {
    let flickrPhoto = photo(for: indexPath)
    guard let thumbnail = flickrPhoto.thumbnail else {
      return []
    }
    let item = NSItemProvider(object: thumbnail)
    let dragItem = UIDragItem(itemProvider: item)
    return [dragItem]
  }
}

// MARK: - UICollectionViewDropDelegate
extension FlickrPhotosViewController: UICollectionViewDropDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      performDropWith coordinator: UICollectionViewDropCoordinator) {
    // 1
    guard let destinationIndexPath = coordinator.destinationIndexPath else {
      return
    }
    
    // 2
    coordinator.items.forEach { dropItem in
      guard let sourceIndexPath = dropItem.sourceIndexPath else {
        return
      }
      
      // 3
      collectionView.performBatchUpdates({
        let image = photo(for: sourceIndexPath)
        removePhoto(at: sourceIndexPath)
        insertPhoto(image, at: destinationIndexPath)
        collectionView.deleteItems(at: [sourceIndexPath])
        collectionView.insertItems(at: [destinationIndexPath])
      }, completion: { _ in
        // 4
        coordinator.drop(dropItem.dragItem,
                         toItemAt: destinationIndexPath)
      })
    }
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      canHandle session: UIDropSession) -> Bool {
    return true
  }

  func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
      return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
  }

}
