//
//  TableViewController.swift
//  Vinci
//
//  Created by Conor Mulligan on 27/04/2018.
//  Copyright © 2018 Conor Mulligan. All rights reserved.
//

import UIKit
import Vinci

/// A `Codable` struct representing an iTunes API entity.
struct Entity: Decodable {
    let wrapperType: String
    let artworkUrl100: String?
    let artistName: String?
    let collectionName: String?
}

/// A `Codable` struct representing an iTunes API entity collection.
struct EntityResponse: Decodable {
    let results: [Entity]
}

/// An example of a custom modifier that applies a gaussian blur filter to the image.
open class BlurModifier: Modifier {
    public var identifier: String

    public init() {
        identifier = "vinci.example.blur"
    }

    public func modify(image: UIImage) -> UIImage {
        let ciImage = CIImage(cgImage: image.cgImage!)

        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(8, forKey: kCIInputRadiusKey)

        guard let outputImage = filter?.outputImage else {
            return image
        }

        guard let cgImage = CIContext().createCGImage(outputImage, from: ciImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }
}

/// Renders a list of Rolling Stones albums using the iTunes API.
class TableViewController: UITableViewController {

    /// The request URL.
    let searchURL = URL(string: "https://itunes.apple.com/search?term=the+rolling+stones&entity=album")!

    /// The photo cell ID.
    let cellID = "PhotoCell"

    /// Media entities.
    var entities = [Entity]()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure Vinci.
        Vinci.shared.debugEnabled = true
        Vinci.shared.cache.debugEnabled = true

        // Load data.
        loadData()
    }

    // MARK: - Data

    /// Requests data from the iTunes Search API, parses the response and update the UI.
    func loadData() {
        let task = URLSession.shared.dataTask(with: searchURL) { [weak self ] (data, response, error) in
            guard let self = self else { return }

            // If the data task returned nil data, show an error message.
            guard data != nil else {
                let message = error?.localizedDescription ?? "data task returned nil data."
                DispatchQueue.main.async {
                    self.showError(message: "Error fetching data: \(message)")
                }
                return
            }

            // Attempt to parse the JSON response.
            // If the JSON decoder failed to decode the response, show an error message.
            do {
                let response = try JSONDecoder().decode(EntityResponse.self, from: data!)
                self.entities = response.results.filter { $0.artworkUrl100 != nil }
            } catch {
                DispatchQueue.main.async {
                    self.showError(message: "Error decoding JSON: \(error.localizedDescription)")
                }
                return
            }

            // Reload the table view.
            DispatchQueue.main.async {
                self.tableView.reloadSections([0], with: .automatic)
            }
        }

        task.resume()
    }

    /// Show an alert controller with the given error message.
    /// - Parameter message: The error message to display.
    func showError(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alertController, animated: true)
    }

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entities.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as! PhotoCell
        cell.tag = indexPath.row

        let entity = entities[indexPath.row]

        cell.titleLabel.text = entity.collectionName
        cell.subtitleLabel.text = entity.artistName

        if let str = entity.artworkUrl100, let url = URL(string: str) {
            let modifiers: [Modifier] = [
                MonoModifier(color: UIColor.gray, intensity: 1.0),
                ScaleModifier(size: cell.photoView.frame.size)
            ]
            Vinci.shared.request(with: url, modifiers: modifiers) { (image, _) in
                if cell.tag == indexPath.row {
                    cell.photoView.image = image
                }
            }
        }

        return cell
    }
}
