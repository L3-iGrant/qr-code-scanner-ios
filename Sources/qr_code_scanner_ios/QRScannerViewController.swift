//
//  Untitled.swift
//  qr_code_scanner_ios
//
//  Created by iGrant on 10/03/25.
//

import UIKit
import AVFoundation
import Vision

public class QRScannerViewController: UIViewController, QRScannerViewDelegate {
    
    private var qrScannerView: QRScannerView!
    
    public weak var delegate: QRScannerViewDelegate?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        qrScannerView = QRScannerView(frame: self.view.bounds)
        self.view.addSubview(qrScannerView)
        qrScannerView.configure(delegate: self)
        qrScannerView.startRunning()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        updateNavigationBarColors(isDark: false)
    }
    
    private func updateNavigationBarColors(isDark: Bool) {
        let titleColor = isDark ? UIColor.white : UIColor.black
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
        let backButtonColor = isDark ? UIColor.white : UIColor.black
        self.navigationController?.navigationBar.tintColor = backButtonColor
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor =  UIColor.black
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor:  UIColor.black
        ]
    }
    
    private func updateNavigationBarAppearance(isDark: Bool) {
        let titleColor = isDark ? UIColor.white : UIColor.black
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
        navigationController?.navigationBar.tintColor = titleColor
    }
    // MARK: - QRScannerViewDelegate
    
    public func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: QRScannerError) {
        delegate?.qrScannerView(qrScannerView, didFailure: error)
    }
    
    public func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String) {
        delegate?.qrScannerView(qrScannerView, didSuccess: code)
    }
    
    public func qrScannerView(_ qrScannerView: QRScannerView, didSuccess binary: [UInt8]) {
        delegate?.qrScannerView(qrScannerView, didSuccess: binary)
    }
    
    public func qrScannerView(_ qrScannerView: QRScannerView, didChangeTorchActive isOn: Bool) {
        delegate?.qrScannerView(qrScannerView, didChangeTorchActive: isOn)
    }
    
    public func qrScannerView(_ qrScannerView: QRScannerView, didChangeBrightness isDark: Bool) {
        updateNavigationBarColors(isDark: isDark)
    }
    
}
