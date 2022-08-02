//
//  CameraViewController.swift
//  Camera
//
//  Created by Shangxin Guo on 2018/9/18.
//  Copyright © 2018 Loong. All rights reserved.
//

import AVFoundation

@objc public enum CameraPosition: Int {
    case front = 0
    case rear
}

protocol BufferSizeProvider: AnyObject {
    var bufferSize: CGSize { get }
    var previewLayer: AVCaptureVideoPreviewLayer? { get }
}

public struct CameraControllerConfigurations {
    public enum Rotation {
        case auto, forcePortrait, forceLandscapeLeft, forceLandscapeRight
    }
    
    /// Rotation to apply to photo after capture
    public let autoRotation: Rotation
    /// Max dimension after image scaled
    public let maxScaledDimension: CGFloat?
    /// Crop rect in view
    public let cropRect: CGRect?
    
    public init(
        autoRotation: @autoclosure ()->Rotation,
        maxScaledDimension: @autoclosure ()->CGFloat? = nil,
        cropRect: @autoclosure ()->CGRect? = nil
    ) {
        self.autoRotation = autoRotation()
        self.maxScaledDimension = maxScaledDimension()
        self.cropRect = cropRect()
    }
}

public class CameraController: UIViewController, BufferSizeProvider {
    
    /// Which camera to use, front or rear
    @objc public private(set) var cameraPosition = CameraPosition.front
    
    /// Mode of flashlight
    @objc public private(set) var flashMode = AVCaptureDevice.FlashMode.off
    
    /// To show crop rect preview or not
    /// - attention: 未完成
    @objc public private(set) var shouldPreviewCropRect = false
    
    /// Controller to display crop rect preview
    private lazy var cropRectPreviewViewController: CropRectPreviewViewController = {
        let it = CropRectPreviewViewController(bufferSizeProvider: self)
        
        self.view.addSubview(it.view)
        it.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            it.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            it.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            it.view.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            it.view.rightAnchor.constraint(equalTo: self.view.rightAnchor)
            ])
        return it
    }()
    
    /// Return true if front camerat exists
    @objc public var canSwitchCameraPosition: Bool {
        return frontCamera != nil
    }
    
    // MARK: AVFoundation Related Properties
    
    var bufferSize = CGSize.zero
    
    private let configuration: CameraControllerConfigurations
    
    private let preparationQueue = DispatchQueue(label: "prepare", qos: .userInteractive)
    
    private let orientationChecker = CamaraOrientationChecker()
    
    private var photoCaptureCompletionBlock: (UIImage?, Error?)->Void = {_, _ in}
    
    private var captureSession: AVCaptureSession?

    /// Store the iOS 10+ only AVCapturePhotoOutput, since version check is not available for stored property
    private var _photoOutput: Any?
    /// Camera output for iOS 11+
    @available(iOS 10, *) private var photoOutput: AVCapturePhotoOutput? {
        get { return _photoOutput as? AVCapturePhotoOutput }
        set { _photoOutput = newValue }
    }
    /// Camera output for iOS 10-
    private var stillImageOutput: AVCaptureStillImageOutput?
    
    /// To generate crop rect preview
    private lazy var videoOutput: AVCaptureVideoDataOutput = {
        if #available(iOS 11, *) {
            let it = AVCaptureVideoDataOutput()
            it.alwaysDiscardsLateVideoFrames = true
            it.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            it.setSampleBufferDelegate(self.cropRectPreviewViewController, queue: videoDataOutputQueue)
            return it
        }
        fatalError()
    }()
    
    private lazy var videoDataOutputQueue: DispatchQueue = {
        if #available(iOS 11, *) {
            return DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        }
        fatalError()
    }()
    
    
    private var frontCamera: AVCaptureDevice?
    private var frontCameraInput: AVCaptureDeviceInput?
    
    private var rearCamera: AVCaptureDevice?
    private var rearCameraInput: AVCaptureDeviceInput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: Initialization
    
    public init(configuration: CameraControllerConfigurations) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        prepare { [weak self] error in
            guard let self = self else { return }
            guard let captureSession = self.captureSession, error == nil else {
                return
            }
            self.previewLayer = {
                let it = AVCaptureVideoPreviewLayer(session: captureSession)
                it.videoGravity = .resizeAspectFill
                it.connection?.videoOrientation = .portrait
                it.zPosition = -1
                self.view.layer.addSublayer(it)
                it.frame = self.view.bounds
                return it
            }()
        }
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pause()
    }
}

// MARK: - Camera Control

public extension CameraController {
    /// Start camera session
    /// - attention: CameraController automatically starts session in viewWillAppear
    @objc func start() {
        preparationQueue.async { [weak self] in
            guard let self = self else { return }
            guard let session = self.captureSession, !session.isRunning else { return }
            session.startRunning()
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.5, animations: {
                    self.view.alpha = 1
                }, completion: nil)
            }
        }
    }
    
    /// Pause camera session
    /// - attention: CameraController automatically pause session in viewWillDisappear
    @objc func pause() {
        view.alpha = 0
        preparationQueue.async { [weak self] in
            guard let self = self else { return }
            guard let session = self.captureSession, session.isRunning else { return }
            session.stopRunning()
        }
    }
    
    /// Switch camera to either front or rear
    @objc func switchCamera() {
        switch cameraPosition {
        case .front: setCamera(to: .rear)
        case .rear: setCamera(to: .front)
        }
    }
    
    /// Set camera to a given position
    @objc func setCamera(to position: CameraPosition) {
        guard position != cameraPosition,
            let session = captureSession,
            let front = frontCameraInput,
            let rear = rearCameraInput
            else { return }
        let oldInput = session.inputs.last ?? rearCameraInput
        var newInput: AVCaptureDeviceInput!
        session.beginConfiguration()
        switch position {
        case .front:
            newInput = front
            session.removeInput(rear)
        case .rear:
            newInput = rear
            session.removeInput(front)
        }
        guard session.canAddInput(newInput) else {
            session.addInput(oldInput!)
            setVideoMirror()
            session.commitConfiguration()
            return
        }
        session.addInput(newInput)
        session.commitConfiguration()
        cameraPosition = position
        setVideoMirror()
    }
    
    private func setVideoMirror() {
        if #available(iOS 11, *) {
            guard let output = photoOutput else { return }
            guard let videoConnection: AVCaptureConnection = {
                for connection in output.connections {
                    for port in connection.inputPorts {
                        if port.mediaType == .video { return connection }
                    }
                }
                return nil
                }() else { return }
            videoConnection.isVideoMirrored = cameraPosition == .front
        }else{
            guard let output = stillImageOutput else { return }
            guard let videoConnection: AVCaptureConnection = {
                for connection in output.connections {
                    for port in connection.inputPorts {
                        if port.mediaType == .video { return connection }
                    }
                }
                return nil
                }() else { return }
            videoConnection.isVideoMirrored = cameraPosition == .front
        }
    }
    
    /// Switch flashlight on or off
    @objc func switchFlashMode() {
        switch flashMode {
        case .off, .auto: setFlashMode(to: .on)
        case .on: setFlashMode(to: .off)
        @unknown default: break
        }
    }
    
    /// Set flashlight to a given mode
    @objc func setFlashMode(to mode: AVCaptureDevice.FlashMode) {
        if let front = frontCamera, front.isFlashModeSupported(mode) {
            do {
                try front.lockForConfiguration()
                front.flashMode = mode
                front.unlockForConfiguration()
            } catch {}
        }
        if let rear = rearCamera, rear.isFlashModeSupported(mode) {
            do {
                try rear.lockForConfiguration()
                rear.flashMode = mode
                rear.unlockForConfiguration()
            } catch {}
        }
        flashMode = mode
    }
    
    // MARK: Capture
    
    /// Take photo. scale, crop, rotation will happen before it returns an image, according to CameraController's configuration.
    @objc func capture(completionHandler: @escaping (UIImage?, Error?)->Void) {
        guard let captureSession = captureSession,
            captureSession.isRunning else {
                DispatchQueue.main.async { completionHandler(nil, CameraControllerError.captureSessionIsMissing) }
                return
            }
        
        let updateImageThenCallCompletionHandler = { [weak self] (image: UIImage?, error: Error?) -> Void in
            
            let crop = { (img: UIImage) -> UIImage in
                guard let self = self else { return img }
                guard let cropRect = self.configuration.cropRect, let layer = self.previewLayer else { return img }
                let topLeft = layer.captureDevicePointConverted(fromLayerPoint: .init(x: cropRect.minX, y: cropRect.minY))
                let topRight = layer.captureDevicePointConverted(fromLayerPoint: .init(x: cropRect.maxX, y: cropRect.minY))
                let bottomLeft = layer.captureDevicePointConverted(fromLayerPoint: .init(x: cropRect.minX, y: cropRect.maxY))

                let convertedPercentageFrame = CGRect(origin: .init(x: max(0, 1 - topLeft.y),
                                                                    y: max(0, topLeft.x)),
                                                      size: .init(width: abs(topRight.y - topLeft.y),
                                                                  height: abs(bottomLeft.x - topLeft.x)))
                return img.cropped(withPercentageRect: convertedPercentageFrame)
            }
            
            let scale = { (img: UIImage) -> UIImage in
                guard let self = self else { return img }
                guard let maxDimension = self.configuration.maxScaledDimension, maxDimension > 0 else { return img }
                return img.scaled(toFitMaxDimension: maxDimension)
            }
            
            let rotate = { (img: UIImage) -> UIImage in
                guard let self = self else { return img }
                let currentOrientation = self.orientationChecker.orientation()
                switch self.configuration.autoRotation {
                case .auto:
                    switch currentOrientation {
                    case .unknown, .portrait, .faceUp, .faceDown:
                        return img
                    case .portraitUpsideDown:
                        return img.rotated(byRadians: .pi)
                    case .landscapeRight:
                        return img.rotated(byRadians: .pi / 2)
                    case .landscapeLeft:
                        return img.rotated(byRadians: .pi / 2 * 3)
                    @unknown default:
                        return img
                    }
                case .forcePortrait:
                    return img
                case .forceLandscapeLeft:
                    return img.rotated(byRadians: .pi / 2 * 3)
                case .forceLandscapeRight:
                    return img.rotated(byRadians: .pi / 2)
                }
            }
            
            let result = image.flatMap(crop).flatMap(scale).flatMap(rotate)
            DispatchQueue.main.async { completionHandler(result, error) }
        }
        
        if #available(iOS 11, *) {
            let settings = AVCapturePhotoSettings()
            if photoOutput?.supportedFlashModes.contains(flashMode) ?? false {
                settings.flashMode = flashMode
            }
            photoCaptureCompletionBlock = updateImageThenCallCompletionHandler
            photoOutput?.capturePhoto(with: settings, delegate: self)
        } else {
            guard let output = stillImageOutput else { return }
            guard let videoConnection: AVCaptureConnection = {
                for connection in output.connections {
                    for port in connection.inputPorts {
                        if port.mediaType == .video { return connection }
                    }
                }
                return nil
            }() else { return }
            output.captureStillImageAsynchronously(from: videoConnection) { buffer, error in
                guard let buffer = buffer else { return }
                let image = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer).flatMap(UIImage.init(data:))
                updateImageThenCallCompletionHandler(image, error)
            }
        }
    }
}


// MARK: - Initializing AVFoudation

extension CameraController {
    private func prepare(completionHandler: @escaping (Error?) -> Void) {
       preparationQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                self.createCaptureSession()
                try self.configureCaptureDevices()
                try self.configureDeviceInputs()
                try self.configurePhotoOutput()
                DispatchQueue.main.async { completionHandler(nil) }
            } catch {
                DispatchQueue.main.async { completionHandler(error) }
            }
        }
    }
    
    private func createCaptureSession() {
        self.captureSession = AVCaptureSession()
    }
    
    private func configureCaptureDevices() throws {
        let cameras: [AVCaptureDevice]
        
        if #available(iOS 11, *) {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            cameras = session.devices
        } else {
            cameras = AVCaptureDevice.devices(for: .video)
        }
        
        guard !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
        
        for camera in cameras {
            if camera.position == .front {
                frontCamera = camera
            }
            
            if camera.position == .back {
                rearCamera = camera
                try camera.lockForConfiguration()
                camera.focusMode = .continuousAutoFocus
                let dimensions = CMVideoFormatDescriptionGetDimensions(camera.activeFormat.formatDescription)
                bufferSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
                camera.unlockForConfiguration()
            }
            
        }
    }
    
    private func configureDeviceInputs() throws {
        guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        if let rearCamera = rearCamera {
            rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
        }
        if let frontCamera = frontCamera {
            frontCameraInput = try? AVCaptureDeviceInput(device: frontCamera)
        }
        
        //默认先启用前摄像头
        if let input = frontCameraInput {
            if captureSession.canAddInput(input) { captureSession.addInput(input) }
            else { throw CameraControllerError.inputsAreInvalid }
            cameraPosition = .front
        } else if let input = rearCameraInput {
            if captureSession.canAddInput(input) { captureSession.addInput(input) }
            cameraPosition = .rear
        } else { throw CameraControllerError.noCamerasAvailable }
    }
    
    private func configurePhotoOutput() throws {
        guard let captureSession = captureSession else { throw CameraControllerError.captureSessionIsMissing }
        captureSession.sessionPreset = .photo
        
        if #available(iOS 11, *) {
            photoOutput = AVCapturePhotoOutput()
            guard let output = photoOutput else { return }
            output.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecType.jpeg])], completionHandler: nil)
            if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
            
            if shouldPreviewCropRect {
                if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
            }
        } else {
            let outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            stillImageOutput = AVCaptureStillImageOutput()
            guard let output = stillImageOutput else { return }
            output.outputSettings = outputSettings
            if captureSession.canAddOutput(output) { captureSession.addOutput(output) }
        }
        captureSession.startRunning()
    }
}

extension CameraController {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
}

@available(iOS 11.0, *)
extension CameraController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        photoCaptureCompletionBlock(image, error)
    }
}

// MARK: - UIImage Extension

fileprivate extension UIImage {
    func rotated(byRadians radians: CGFloat) -> UIImage {
        let newSize: CGSize = {
            var it = CGRect(origin: .zero, size: size)
                .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
                .size
            it.width = floor(it.width)
            it.height = floor(it.height)
            return it
        }()
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        context.rotate(by: CGFloat(radians))
        draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
    
    func scaled(toFitMaxDimension maxDimension: CGFloat) -> UIImage {
        let widthOrHeight = max(size.width, size.height)
        guard widthOrHeight > 0 else { return self }
        let scale = maxDimension / widthOrHeight
        let newHeight = size.height * scale
        let newWidth = size.width * scale
        
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
    
    func cropped(withPercentageRect rect: CGRect) -> UIImage {
        let offset = CGPoint(x: -rect.origin.x * size.width, y: -rect.origin.y * size.height)
        let newSize = CGSize(width: rect.width * size.width, height: rect.height * size.height)
        UIGraphicsBeginImageContext(newSize)
        draw(in: .init(origin: offset, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? self
    }
}
