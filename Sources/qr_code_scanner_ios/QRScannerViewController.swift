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

    private let gradientView = UIView()
    private let gradientLayer = CAGradientLayer()
    private var savedNavBarTintColor: UIColor?
    private var savedNavBarTitleAttributes: [NSAttributedString.Key: Any]?
    private let torchButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var isTorchOn = false

    public override func viewDidLoad() {
        super.viewDidLoad()

        qrScannerView = QRScannerView(frame: self.view.bounds)
        self.view.addSubview(qrScannerView)
        qrScannerView.configure(delegate: self)
        qrScannerView.startRunning()
        setupGradientOverlay()
        setupNavigationBar()
        setupTorchButton()
        setupHintLabel()
    }

    private func setupGradientOverlay() {
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.isUserInteractionEnabled = false
        view.addSubview(gradientView)
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 120)
        ])
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = gradientView.bounds
    }

    private func setupNavigationBar() {
        // Save original nav bar state to restore on exit
        savedNavBarTintColor = navigationController?.navigationBar.tintColor
        savedNavBarTitleAttributes = navigationController?.navigationBar.titleTextAttributes

        // Disable iOS 26 default circular back button styling
        navigationItem.hidesBackButton = true
        if #available(iOS 26.0, *) {
            navigationItem.backBarButtonItem?.hidesSharedBackground = true
        }

        // Default to white — always readable over dark gradient overlay
        updateNavigationBarColors(isDark: true)
    }

    private func updateNavigationBarColors(isDark: Bool) {
        let color = isDark ? UIColor.white : UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: color
        ]
        self.navigationController?.navigationBar.tintColor = color
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Re-apply white after WXNavigationBar resets to defaults during push
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        navigationController?.navigationBar.tintColor = .white
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore original nav bar appearance
        navigationController?.navigationBar.tintColor = savedNavBarTintColor ?? UIColor.black
        navigationController?.navigationBar.titleTextAttributes = savedNavBarTitleAttributes ?? [
            .foregroundColor: UIColor.black
        ]
    }

    private func updateNavigationBarAppearance(isDark: Bool) {
        let titleColor = isDark ? UIColor.white : UIColor.black
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
        navigationController?.navigationBar.tintColor = titleColor
    }

    private func setupTorchButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = UIImage(systemName: "flashlight.off.fill", withConfiguration: config)
        torchButton.setImage(image, for: .normal)
        torchButton.tintColor = .white
        torchButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        torchButton.layer.cornerRadius = 25
        torchButton.clipsToBounds = true
        torchButton.translatesAutoresizingMaskIntoConstraints = false
        torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        view.addSubview(torchButton)
        NSLayoutConstraint.activate([
            torchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            torchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            torchButton.widthAnchor.constraint(equalToConstant: 50),
            torchButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func toggleTorch() {
        isTorchOn.toggle()
        qrScannerView.setTorchActive(isOn: isTorchOn)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let imageName = isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill"
        torchButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        torchButton.backgroundColor = isTorchOn
            ? UIColor.white.withAlphaComponent(0.85)
            : UIColor.black.withAlphaComponent(0.4)
        torchButton.tintColor = isTorchOn ? .black : .white
    }

    private func setupHintLabel() {
        hintLabel.text = "Point camera at a QR code"
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        hintLabel.font = .systemFont(ofSize: 15, weight: .medium)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        let focusWidth = UIScreen.main.bounds.width * 0.618
        let safeTop = view.safeAreaInsets.top > 0 ? view.safeAreaInsets.top : 44
        let navBarHeight: CGFloat = 44
        let availableHeight = UIScreen.main.bounds.height - safeTop - navBarHeight
        let focusYBottom = safeTop + navBarHeight + (availableHeight - focusWidth) / 2 - 30 + focusWidth

        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: focusYBottom + 16)
        ])
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
        // Nav bar always white — gradient ensures readability regardless of scene brightness
    }

}
