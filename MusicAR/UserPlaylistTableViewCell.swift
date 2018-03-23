//
//  UserPlaylistTableViewCell.swift
//  MusicAR
//
//  Created by Taylor Franklin on 3/22/18.
//  Copyright © 2018 Taylor Franklin. All rights reserved.
//

import UIKit

class UserPlaylistTableViewCell: UITableViewCell {
    
    @IBOutlet weak var playlistImageView: UIImageView!
    @IBOutlet weak var playlistTitle: UILabel!
    @IBOutlet weak var playlistTracksLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
