//
//  ViewController.swift
//  qr-code-scanner-ios
//
//  Created by rebinkpmna@gmail.com on 07/11/2021.
//  Copyright (c) 2021 rebinkpmna@gmail.com. All rights reserved.
//

import UIKit
import qr_code_scanner_ios

class ViewController: UIViewController,QRScannerViewDelegate {
    
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var scannedResult: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func scanButton(_ sender: Any) {
        let newVC = UIViewController()
        let qrScannerView = QRScannerView(frame: newVC.view.bounds)
        newVC.view.addSubview(qrScannerView)
        qrScannerView.configure(delegate: self)
        qrScannerView.startRunning()
        newVC.title = "Scan"
        self.navigationController?.pushViewController(newVC, animated: true)
    }
    
    func qrScannerView(_ qrScannerView: QRScannerView, didSuccess binary: [UInt8]) {
        scannedResult.text = "\(binary)"
        self.navigationController?.popViewController(animated: true)
    }
    
    func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String) {
        scannedResult.text = code
        self.navigationController?.popViewController(animated: true)
    }
    
    func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: QRScannerError) {
        print(error.localizedDescription)
        self.navigationController?.popViewController(animated: true)
    }
}

