import UIKit
import PPCamera
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var modelButton: UIButton!
    
    var isFlash = false
    var isFront = false

    let camera = CameraController(configuration: .init(autoRotation: .auto))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
//        let tap = UITapGestureRecognizer(target: self, action: #selector(capture))
//        view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.addSubview(camera.view)
        camera.view.frame = cameraView.bounds
    }
    
    @objc func capture() {
        camera.capture { [unowned self] image, _ in
            let vc = UIViewController()
            let imageView = UIImageView()
            imageView.image = image
            imageView.contentMode = .scaleAspectFit
            vc.view.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: vc.view.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                imageView.leftAnchor.constraint(equalTo: vc.view.leftAnchor),
                imageView.rightAnchor.constraint(equalTo: vc.view.rightAnchor)
                ])
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.cancel))
            vc.view.addGestureRecognizer(tap)
            self.present(vc, animated: true, completion: nil)
        }
        
    }
    
    @objc func cancel() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func flashButtonAction(_ sender: Any) {
        let model = isFlash ? AVCaptureDevice.FlashMode.off : AVCaptureDevice.FlashMode.on
        self.camera.setFlashMode(to: model)
        isFlash = !isFlash
        let string = isFlash ? "闪光灯(开)" : "闪光灯(关)"
        flashButton.setTitle(string, for: .normal)
    }
    
    @IBAction func takePhotoButtonAction(_ sender: Any) {
        camera.capture { [unowned self] image, _ in
            let vc = UIViewController()
            let imageView = UIImageView()
            imageView.image = image
            imageView.contentMode = .scaleAspectFit
            vc.view.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: vc.view.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
                imageView.leftAnchor.constraint(equalTo: vc.view.leftAnchor),
                imageView.rightAnchor.constraint(equalTo: vc.view.rightAnchor)
                ])
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.cancel))
            vc.view.addGestureRecognizer(tap)
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func changeCameraButtonAction(_ sender: Any) {
        self.camera.switchCamera()
        isFront = !isFront
        let string = isFront ? "前置" : "后置"
        modelButton.setTitle(string, for: .normal)
    }
    
}



