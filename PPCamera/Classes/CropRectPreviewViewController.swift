import UIKit
import AVFoundation

#if canImport(Vision)
import Vision

class CropRectPreviewViewController: UIViewController {
    var previewRectLayer: CAShapeLayer!
    var verticesLayer: CAShapeLayer!
    var overlayLayer: CALayer!
    weak var bufferSizeProvider: BufferSizeProvider!
    private var bufferSize: CGSize { return bufferSizeProvider.bufferSize }
    
    init(bufferSizeProvider: BufferSizeProvider) {
        self.bufferSizeProvider = bufferSizeProvider
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overlayLayer = {
            let it = CALayer()
            view.layer.addSublayer(it)
            return it
        }()
        
        previewRectLayer = {
            let it = CAShapeLayer()
            it.strokeColor = UIColor.orange.cgColor
            it.fillColor = UIColor.orange.withAlphaComponent(0.3).cgColor
            it.lineWidth = 2
            it.lineCap = .round
            overlayLayer.addSublayer(it)
            
            return it
        }()
        
        verticesLayer = {
            let it = CAShapeLayer()
            it.strokeColor = UIColor.blue.cgColor
            it.fillColor = UIColor.blue.withAlphaComponent(0.3).cgColor
            it.lineWidth = 2
            it.lineCap = .round
            overlayLayer.addSublayer(it)
            
            return it
        }()
    }
}

extension CropRectPreviewViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard #available(iOS 11, *) else { fatalError() }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectRectanglesRequest { [weak self] req, error in
            guard let observation = req.results?.first as? VNRectangleObservation else { return }
            DispatchQueue.main.async {
                self?.updatePreviewRectFrame(accordingTo: observation)
            }
        }
        try? handler.perform([request])
    }
    
    @available(iOS 11.0, *)
    private func updatePreviewRectFrame(accordingTo observation: VNRectangleObservation) {
        
        let xScale: CGFloat = (bufferSizeProvider.previewLayer?.bounds.size.height ?? 0) / bufferSize.width
        let yScale: CGFloat = (bufferSizeProvider.previewLayer?.bounds.size.width ?? 0) / bufferSize.height
        
        var scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        
        let scaledSize = bufferSize.scaled(scale)
        
        let objectBounds = VNImageRectForNormalizedRect(
            observation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
        
        let topLeft = observation.topLeftVertex(toContentSize: scaledSize)
        let topRight = observation.topRightVertex(toContentSize: scaledSize)
        let bottomLeft = observation.bottomLeftVertex(toContentSize: scaledSize)
        let bottomRight = observation.bottomRightVertex(toContentSize: scaledSize)
        
        let pathB = UIBezierPath()
        pathB.move(to: topLeft)
        pathB.addLine(to: topRight)
        pathB.addLine(to: bottomRight)
        pathB.addLine(to: bottomLeft)
        pathB.close()

        let path = UIBezierPath(rect: objectBounds)
        previewRectLayer.path = path.cgPath
        verticesLayer.path = pathB.cgPath
        let transform = CGAffineTransform.identity
            .translatedBy(x: scaledSize.height, y: 0)
            .rotated(by: .pi / 2.0)
        previewRectLayer.setAffineTransform(transform)
        verticesLayer.setAffineTransform(transform)
    }

}

extension CGSize {
    fileprivate func scaled(_ scale: CGFloat) -> CGSize {
        return .init(width: width * scale, height: height * scale)
    }
}
#endif
