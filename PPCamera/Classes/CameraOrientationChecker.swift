import ImageIO
import CoreMotion

/// 用以判断设备当前的朝向。
public class CamaraOrientationChecker {
    var motionManager: CMMotionManager!
    
    init() {
        setupMotionManager()
    }
    
    deinit {
        teardownMotionManager()
    }
    
    /// 设备朝向是否与屏幕朝向相匹配
    func deviceOrientationMatchesInterfaceOrientation() -> Bool {
        return orientation() == UIDevice.current.orientation
    }
    
    /// 当前的设备朝向
    func orientation() -> UIDeviceOrientation {
        return _actualDeviceOrientationFromAccelerometer()
    }
    
    private func setupMotionManager() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
#if !TARGET_IPHONE_SIMULATOR
        motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = 0.005
        motionManager.startAccelerometerUpdates()
#endif
    }
    
    private func teardownMotionManager() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
#if !TARGET_IPHONE_SIMULATOR
        motionManager.stopAccelerometerUpdates()
        motionManager = nil
#endif
    }
    
    func _actualDeviceOrientationFromAccelerometer() -> UIDeviceOrientation {
#if TARGET_IPHONE_SIMULATOR
        return .portrait
#else
        guard let acceleration: CMAcceleration = motionManager.accelerometerData?.acceleration else { return .portrait }
        if (acceleration.z) < -0.90 { return .faceUp }
        if (acceleration.z) > 0.90 { return .faceDown }

        let dvs = abs(acceleration.x) + abs(acceleration.y)
        let scaling: CGFloat = 1.0 / CGFloat(dvs == 0 ? 1 : dvs)
        let x = CGFloat((acceleration.x) * Double(scaling))
        let y = CGFloat((acceleration.y) * Double(scaling))
        if x < -0.5 { return .landscapeLeft }
        if x > 0.5  { return .landscapeRight }
        if y > 0.5  { return .portraitUpsideDown }
        return .portrait
#endif
    }
}
