//
//  QRScannerView.swift
//  QRScanner
//
//  Created by wbi on 2019/10/16.
//  Copyright © 2019 Mercari, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

// MARK: - QRScannerViewDelegate
public protocol QRScannerViewDelegate: AnyObject {
    // Required
    func qrScannerView(_ qrScannerView: QRScannerView, didFailure error: QRScannerError)
    func qrScannerView(_ qrScannerView: QRScannerView, didSuccess code: String)
    func qrScannerView(_ qrScannerView: QRScannerView, didSuccess binary: [UInt8])
    
    // Optional
    func qrScannerView(_ qrScannerView: QRScannerView, didChangeTorchActive isOn: Bool)
    func qrScannerView(_ qrScannerView: QRScannerView, didChangeBrightness isDark: Bool)

}

public extension QRScannerViewDelegate where Self: AnyObject {
    func qrScannerView(_ qrScannerView: QRScannerView, didChangeTorchActive isOn: Bool) {}
    func qrScannerView(_ qrScannerView: QRScannerView, didChangeBrightness isDark: Bool) {}
}

// MARK: - QRScannerView
@IBDesignable
public class QRScannerView: UIView {
    
    // MARK: - Input
    public struct Input {
        let focusImage: UIImage?
        let focusImagePadding: CGFloat?
        let animationDuration: Double?
        let isBlurEffectEnabled: Bool?
        
        public static var `default`: Input {
            return .init(focusImage: nil, focusImagePadding: nil, animationDuration: nil, isBlurEffectEnabled: nil)
        }
        
        public init(focusImage: UIImage? = nil, focusImagePadding: CGFloat? = nil, animationDuration: Double? = nil, isBlurEffectEnabled: Bool? = nil) {
            self.focusImage = focusImage
            self.focusImagePadding = focusImagePadding
            self.animationDuration = animationDuration
            self.isBlurEffectEnabled = isBlurEffectEnabled
        }
    }
    
    // MARK: - Public Properties
    @IBInspectable
    public var focusImage: UIImage?
    
    @IBInspectable
    public var focusImagePadding: CGFloat = 8.0
    
    @IBInspectable
    public var animationDuration: Double = 0.5
    
    @IBInspectable
    public var isBlurEffectEnabled: Bool = false
    
    private var readableObject: AVMetadataMachineReadableCodeObject?
    // MARK: - Public
    
    public func getQRCodeDataFromImage(image: UIImage) -> String?{
//        let QRCode = self.readQRCode(image)
        if let ciImage:CIImage=CIImage(image: image) {
            var qrCodeLink = ""
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])
            
            let features = detector?.features(in: ciImage) ?? []
            for feature in features {
                qrCodeLink += (feature as? CIQRCodeFeature)?.messageString ?? ""
            }
            if qrCodeLink=="" {
                print("nothing")
                return nil
            }else{
                print("message: \(qrCodeLink)")
                return qrCodeLink
            }
        } else {
            print("invalid QR Code")
            return nil
        }
    }
    
    public func configure(delegate: QRScannerViewDelegate, input: Input = .default) {
        self.delegate = delegate
        if let focusImage = input.focusImage {
            self.focusImage = focusImage
        }
        if let focusImagePadding = input.focusImagePadding {
            self.focusImagePadding = focusImagePadding
        }
        if let animationDuration = input.animationDuration {
            self.animationDuration = animationDuration
        }
        if let isBlurEffectEnabled = input.isBlurEffectEnabled {
            self.isBlurEffectEnabled = isBlurEffectEnabled
        }
        
        configureSession()
        addPreviewLayer()
        setupBlurEffectView()
        setupImageViews()
    }
    
    public func startRunning() {
        guard isAuthorized() else { return }
        guard !session.isRunning else { return }
        videoDataOutputEnable = false
        metadataOutputEnable = true
        metadataQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    public func stopRunning() {
        guard session.isRunning else { return }
        videoDataQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        metadataOutputEnable = false
        videoDataOutputEnable = false
    }
    
    public func rescan() {
        guard isAuthorized() else { return }
        if isBlurEffectEnabled {
            blurEffectView.isHidden = true
        }
        focusImageView.removeFromSuperview()
        qrCodeImageView.removeFromSuperview()
        setupImageViews()
        qrCodeImage = nil
        videoDataOutputEnable = false
        metadataOutputEnable = true
    }
    
    public func setTorchActive(isOn: Bool) {
        assert(Thread.isMainThread)
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              videoDevice.hasTorch, videoDevice.isTorchAvailable,
              (metadataOutputEnable || videoDataOutputEnable) else {
                  return
              }
        try? videoDevice.lockForConfiguration()
        videoDevice.torchMode = isOn ? .on : .off
        videoDevice.unlockForConfiguration()
    }
    
    deinit {
        setTorchActive(isOn: false)
        focusImageView.removeFromSuperview()
        qrCodeImageView.removeFromSuperview()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        removePreviewLayer()
        torchActiveObservation = nil
    }
    
    // MARK: - Private
    
    private weak var delegate: QRScannerViewDelegate?
    private let metadataQueue = DispatchQueue(label: "metadata.session.qrreader.queue")
    private let videoDataQueue = DispatchQueue(label: "videoData.session.qrreader.queue")
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var focusImageView = UIImageView()
    private var qrCodeImageView = UIImageView()
    private var metadataOutput = AVCaptureMetadataOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var metadataOutputEnable = false
    private var videoDataOutputEnable = false
    private var torchActiveObservation: NSKeyValueObservation?
    private var qrCodeImage: UIImage?
    private lazy var blurEffectView: UIVisualEffectView = {
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurEffectView.frame = self.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return blurEffectView
    }()
    
    private enum AuthorizationStatus {
        case authorized, notDetermined, restrictedOrDenied
    }
    
    private func isAuthorized() -> Bool {
        return authorizationStatus() == .authorized
    }
    
    private func authorizationStatus() -> AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                return .authorized
            case .notDetermined:
                failure(.unauthorized(.notDetermined))
                return .notDetermined
            case .denied:
                failure(.unauthorized(.denied))
                return .restrictedOrDenied
            case .restricted:
                failure(.unauthorized(.restricted))
                return .restrictedOrDenied
            @unknown default:
                return .restrictedOrDenied
        }
    }
    
    private func configureSession() {
        // check device initialize
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            failure(.deviceFailure(.videoUnavailable))
            return
        }
        
        // check input
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice), session.canAddInput(videoInput) else {
            failure(.deviceFailure(.inputInvalid))
            return
        }
        
        // check metadata output
        guard session.canAddOutput(metadataOutput) else {
            failure(.deviceFailure(.metadataOutputFailure))
            return
        }
        
        // check videoData output
        guard session.canAddOutput(videoDataOutput) else {
            failure(.deviceFailure(.videoDataOutputFailure))
            return
        }
        
        // commit session
        session.beginConfiguration()
        session.addInput(videoInput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
        session.addOutput(metadataOutput)
        metadataOutput.metadataObjectTypes = [.qr]
        
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        session.addOutput(videoDataOutput)
        
        session.commitConfiguration()
        
        // torch observation
        if videoDevice.hasTorch {
            torchActiveObservation = videoDevice.observe(\.isTorchActive, options: .new) { [weak self] _, change in
                self?.didChangeTorchActive(isOn: change.newValue ?? false)
            }
        }
        
        // start running
        if authorizationStatus() == .notDetermined {
            videoDataOutputEnable = false
            metadataOutputEnable = true
            metadataQueue.async { [weak self] in
                self?.session.startRunning()
            }
        }
    }
    
    private func setupBlurEffectView() {
        guard isBlurEffectEnabled else { return }
        blurEffectView.isHidden = true
        addSubview(blurEffectView)
    }
    
    private func setupImageViews() {
        let width = UIScreen.main.bounds.width * 0.618
        let xPos = UIScreen.main.bounds.width * 0.191
        let yPos = UIScreen.main.bounds.height * 0.191
        focusImageView = UIImageView(frame: CGRect(x: xPos, y: yPos, width: width, height: width))
        focusImageView.image = focusImage ?? UIImage(named: "scan_qr_focus", in: Bundle.init(for: self.classForCoder), compatibleWith: nil)
        addSubview(focusImageView)
        
        qrCodeImageView = UIImageView()
        qrCodeImageView.contentMode = .scaleAspectFill
        addSubview(qrCodeImageView)
    }
    
    private func getResourcesBundle(vc: AnyClass) -> Bundle? {
        //        return nil
        
        //SDK
        let bundle = Bundle(for: vc.self)
        guard let resourcesBundleUrl = bundle.resourceURL?.appendingPathComponent("qr-code-scanner-ios.bundle") else {
            return nil
        }
        return Bundle(url: resourcesBundleUrl)
    }
    
    private func addPreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = self.bounds
        layer.addSublayer(previewLayer)
        
        self.previewLayer = previewLayer
    }
    
    private func removePreviewLayer() {
        previewLayer?.removeFromSuperlayer()
    }

 private func calculateBrightness(from pixelBuffer: CVPixelBuffer) -> CGFloat {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var totalBrightness: CGFloat = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixel = baseAddress.load(fromByteOffset: y * bytesPerRow + x * 4, as: UInt32.self)
                let r = CGFloat((pixel >> 16) & 0xFF) / 255.0
                let g = CGFloat((pixel >> 8) & 0xFF) / 255.0
                let b = CGFloat(pixel & 0xFF) / 255.0
                totalBrightness += (r + g + b) / 3.0
            }
        }
        
        return totalBrightness / CGFloat(width * height)
    }
    
    private func moveImageViews(qrCode: String, corners: [CGPoint], binary: [UInt8]?) {
        assert(Thread.isMainThread)
        
        let path = UIBezierPath()
        path.move(to: corners[0])
        corners[1..<corners.count].forEach() {
            path.addLine(to: $0)
        }
        path.close()
        
        let aSide: CGFloat
        let bSide: CGFloat
        if corners[0].x < corners[1].x {
            aSide = corners[0].x - corners[1].x
            bSide = corners[1].y - corners[0].y
        } else {
            aSide = corners[2].y - corners[1].y
            bSide = corners[2].x - corners[1].x
        }
        let degrees = atan(aSide / bSide)
        
        var maxSide: CGFloat =  hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y)
        for (index, _) in corners.enumerated() {
            if index == 3 { break }
            let side = hypot(corners[index].x - corners[index+1].x, corners[index].y - corners[index+1].y)
            maxSide = side > maxSide ? side : maxSide
        }
        maxSide += focusImagePadding * 2
        
        UIView.animate(withDuration: animationDuration, animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.focusImageView.frame = path.bounds
            let center = strongSelf.focusImageView.center
            strongSelf.focusImageView.frame.size = CGSize(width: maxSide, height: maxSide)
            strongSelf.focusImageView.center = center
            strongSelf.focusImageView.transform = CGAffineTransform.identity.rotated(by: degrees)
            
            strongSelf.qrCodeImageView.frame = path.bounds
            strongSelf.qrCodeImageView.center = center
        }, completion: { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.qrCodeImageView.image = strongSelf.qrCodeImage
            if strongSelf.isBlurEffectEnabled {
                strongSelf.blurEffectView.isHidden = false
            }
            strongSelf.success(qrCode,bytes: binary)
        })
    }
    
    private func failure(_ error: QRScannerError) {
        delegate?.qrScannerView(self, didFailure: error)
    }
    
    private func success(_ code: String,bytes: [UInt8]?) {
        if !code.isEmpty{
            delegate?.qrScannerView(self, didSuccess: code)
        } else {
            delegate?.qrScannerView(self, didSuccess: bytes ?? [])
        }
    }
    
    private func didChangeTorchActive(isOn: Bool) {
        delegate?.qrScannerView(self, didChangeTorchActive: isOn)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerView: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard metadataOutputEnable else { return }
        if let metadataObject = metadataObjects.first {
            guard let readableObject = previewLayer?.transformedMetadataObject(for: metadataObject) as? AVMetadataMachineReadableCodeObject, metadataObject.type == .qr else { return }
            
            if let stringValue = readableObject.stringValue, stringValue != "PK\u{03}\u{04}\n"{
                metadataOutputEnable = false
                videoDataOutputEnable = true
                
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.setTorchActive(isOn: false)
                    strongSelf.moveImageViews(qrCode: stringValue, corners: readableObject.corners, binary: nil)
                }
            } else {
                self.readableObject = readableObject
                if let data = ((readableObject.value(forKeyPath: "_internal.basicDescriptor") as? [String:Any])?["BarcodeRawData"]) as? Data {
                    var byteArray = Binary.init(bytes: [UInt8](data))
                    var symbolVersion = 0
                    if let symblVer = (((readableObject.value(forKeyPath: "_internal.basicDescriptor") as? [String:Any])?["CodeProperties"]as? [String:Any])?["SymbolVersion"] as? Int) {
                        symbolVersion = symblVer
                    }else if let symblVer = ((readableObject.value(forKeyPath: "_internal.basicDescriptor") as? [String:Any])?["SymbolVersion"] as? Int) {// From iOS 15 onwards
                        symbolVersion = symblVer
                    }
                    decode(&byteArray, symbolVersion: symbolVersion)
                }
            }
        }
    }
    
    
    public func readQRCodeData(in image: UIImage, data: Data, symbolVersion: Int) {
        var byteArray = Binary.init(bytes: [UInt8](data))
        decode(&byteArray, symbolVersion: symbolVersion,fromImage: true)
    }
    
    private func decode(_ binary: inout Binary, symbolVersion: Int, fromImage: Bool = false) {
        let modeBitsLength = 4
        guard binary.bitsWithInternalOffsetAvailable(modeBitsLength) else { return }
        let supportedModes: [Mode] = [.structuredAppend, .byte, .endOfMessage]
        
        let modeBits = binary.next(bits: modeBitsLength)
        guard let mode = Mode(rawValue: modeBits),
              supportedModes.contains(mode) else {
                  return
              }
        guard mode != .endOfMessage else { return }
        if case .structuredAppend = mode {
        } else if case .byte = mode {
            guard let numberOfBitsInLengthFiled = mode.numberOfBitsInLengthFiled(for: symbolVersion),
                  let numberOfBitsPerCharacter = mode.numberOfBitsPerCharacter else { return }
            let totalCharacterCount = binary.next(bits: numberOfBitsInLengthFiled)
            var bytes: [UInt8] = []
            for _ in 0..<totalCharacterCount {
                let byte = binary.next(bits: numberOfBitsPerCharacter)
                bytes.append(UInt8(byte))
            }
            //            print("bytes -- \(bytes)")
            metadataOutputEnable = false
            videoDataOutputEnable = true
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.setTorchActive(isOn: false)
                if fromImage {
                    let text = String(bytes: bytes, encoding: .utf8) ?? ""
                    if text != "" {
                        var charArray: [UInt8] = []
                        for char in text {
                            charArray.append(char.unicodeScalars.map { UInt8($0.value)}.reduce(0, +))
                        }
                        print(charArray)
                        strongSelf.success("",bytes: [UInt8](charArray))
                    } else {
                        strongSelf.success("",bytes: [UInt8](bytes))
                    }
                } else {
                    // check if data is utf8 decodable or not.eg - Philippines cert is utf8 encoded and Indian cert is not
                    let text = String(bytes: bytes, encoding: .utf8) ?? ""
                    if text != "" {
                        var charArray: [UInt8] = []
                        for char in text {
                            charArray.append(char.unicodeScalars.map { UInt8($0.value)}.reduce(0, +))
                        }
                        print(charArray)
                        strongSelf.moveImageViews(qrCode: "", corners: self?.readableObject?.corners ?? [CGPoint.zero], binary: [UInt8](charArray))
                    } else {
                        strongSelf.moveImageViews(qrCode: "", corners: self?.readableObject?.corners ?? [CGPoint.zero], binary: [UInt8](bytes))
                    }
                }
            }
        }
        decode(&binary,symbolVersion: symbolVersion)
    }
    
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension QRScannerView: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let brightness = calculateBrightness(from: pixelBuffer)
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.qrScannerView(self!, didChangeBrightness: brightness < 0.5)
        }
        guard videoDataOutputEnable else { return }
        guard let qrCodeImage = getImageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        self.qrCodeImage = qrCodeImage
        videoDataOutputEnable = false
    }
    private func getImageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        let scale = UIScreen.main.scale
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        else {
            return nil
        }
        guard let cgImage = context.makeImage() else { return nil }
        let sampleBuffer = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        return readQRCode(sampleBuffer)
    }
    
    public func readQRCode(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        guard let features = detector?.features(in: ciImage) else { return nil }
        guard let feature = features.first as? CIQRCodeFeature else { return nil }
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -ciImage.extent.size.height)
        let path = UIBezierPath()
        path.move(to: feature.topLeft.applying(transform))
        path.addLine(to: feature.topRight.applying(transform))
        path.addLine(to: feature.bottomRight.applying(transform))
        path.addLine(to: feature.bottomLeft.applying(transform))
        path.close()
        return image.crop(path)
    }
}

private extension UIImage {
    func crop(_ path: UIBezierPath) -> UIImage? {
        let rect = CGRect(origin: CGPoint(), size: CGSize(width: size.width * scale, height: size.height * scale))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        UIColor.clear.setFill()
        UIRectFill(rect)
        path.addClip()
        draw(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let xPos = path.bounds.origin.x * scale
        let yPos = path.bounds.origin.y * scale
        let width = path.bounds.size.width * scale
        let height = path.bounds.size.height * scale
        guard let croppedImage = image?.cgImage?.cropping(to: CGRect(x: xPos, y: yPos, width: width, height: height))
        else {return nil}
        return UIImage(cgImage: croppedImage, scale: scale, orientation: imageOrientation)
    }
}

enum SymbolType {
    case small
    case medium
    case large
    
    init?(version: Int) {
        if 1 <= version, version <= 9 {
            self = .small
        } else if 10 <= version, version <= 26 {
            self = .medium
        } else if 27 <= version, version <= 40 {
            self = .large
        } else {
            return nil
        }
    }
}

enum Mode: Int {
    case numeric              = 1 // 0001 数字
    case alphanumeric         = 2 // 0010 英数字
    case byte                 = 4 // 0100 バイト
    case kanji                = 8 // 1000 漢字
    case structuredAppend     = 3 // 0011 構造的連接
    case eci                  = 7 // 0111 ECI
    case fnc1InFirstPosition  = 5 // 0101 FNC1（1番目の位置）
    case fnc1InSecondPosition = 9 // 1001 FNC1（1番目の位置）
    case endOfMessage         = 0 // 0000 終端パターン
    
    var description: String {
        switch self {
            case .numeric:              return "0001 数字"
            case .alphanumeric:         return "0010 英数字"
            case .byte:                 return "0100 バイト"
            case .kanji:                return "1000 漢字"
            case .structuredAppend:     return "0011 構造的連接"
            case .eci:                  return "0111 ECI"
            case .fnc1InFirstPosition:  return "0101 FNC1（1番目の位置）"
            case .fnc1InSecondPosition: return "1001 FNC1（1番目の位置）"
            case .endOfMessage:         return "0000 終端パターン"
        }
    }
    
    var hasNumberOfBitsInLengthFiled: Bool {
        switch self {
            case .numeric, .alphanumeric, .byte, .kanji:
                return true
            default:
                return false
        }
    }
    
    var numberOfBitsPerCharacter: Int? {
        switch self {
            case .numeric: return 10
            case .alphanumeric: return 11
            case .byte: return 8
            case .kanji: return 13
            default: return nil
        }
    }
    
    func numberOfBitsInLengthFiled(for symbolVersion: Int) -> Int? {
        guard let symbolType = SymbolType(version: symbolVersion) else { return nil }
        switch self {
            case .numeric:
                switch symbolType {
                    case .small: return 10
                    case .medium: return 12
                    case .large: return 14
                }
                
            case .alphanumeric:
                switch symbolType {
                    case .small: return 9
                    case .medium: return 11
                    case .large: return 13
                }
                
            case .byte:
                switch symbolType {
                    case .small: return 8
                    case .medium: return 16
                    case .large: return 16
                }
                
            case .kanji:
                switch symbolType {
                    case .small: return 8
                    case .medium: return 10
                    case .large: return 12
                }
                
            default:
                return nil
        }
    }
}
