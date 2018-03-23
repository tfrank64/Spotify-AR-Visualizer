
import Foundation

extension UIImageView {
    public func imageFromServerURL(url: URL, defaultImage: String?) {
        if let defaultImg = defaultImage {
            self.image = UIImage(named: defaultImg)
        }
        
        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
            guard error == nil, let imageData = data else {
                print("Error getting image data: \(String(describing: error?.localizedDescription))")
                return
            }
            DispatchQueue.main.async {
                let image = UIImage(data: imageData)
                self.image = image
            }
            
        }).resume()
    }
}
