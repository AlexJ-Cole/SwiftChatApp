//
//  PhotoViewerViewController.swift
//  FireChat
//
//  Created by Alex Cole on 9/27/20.
//

import UIKit
import SDWebImage

///Controller to display photos sent as attachments in a conversation, presented when a photo is tapped on in `ChatViewController`
final class PhotoViewerViewController: UIViewController {
    
    private var url: URL
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    init(with url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Photo"
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(imageView)
        view.backgroundColor = .black
        imageView.sd_setImage(with: url, completed: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds
    }
    
}
