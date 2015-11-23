//
//  ViewController.swift
//  NirWebImage
//
//  Created by Nirvana on 11/15/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var testImageView: UIImageView!
    
    @IBOutlet weak var testButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        testImageView.nir_setImageWithURL(NSURL(string: "https://camo.githubusercontent.com/2de532f84bb14fed9949eda6211747493d624664/68747470733a2f2f7777772e706572666563742e6f72672f696d616765732f69636f6e5f313238783132382e706e67")!)
        
        testButton.nir_setImageWithURL(NSURL(string: "https://camo.githubusercontent.com/2de532f84bb14fed9949eda6211747493d624664/68747470733a2f2f7777772e706572666563742e6f72672f696d616765732f69636f6e5f313238783132382e706e67")!, forState: UIControlState.Normal)
        testButton.imageView?.contentMode = UIViewContentMode.ScaleAspectFit
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func testAction(sender: AnyObject) {
        print("Clicked")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

