import Foundation
import CoreMotion
import CoreLocation

public protocol JounceKnockDelegate: class {
    func chartData(jounce: Double, isDoubleKnock: Bool)
}

public class JounceKnockDetectorWorker {
    
    let limitDifference = 2.5
    let numberOfKnocksNeeded = 2
    let minimumTimeBetweenSingleKnocks: TimeInterval = 0.05 // was 0.1
    public var maximumTimeBetweenSingleKnocks: TimeInterval = 1.5
    public var timeNeededBetweenKnockOperations: TimeInterval = 2.0
    private var lastCapturedData: CMAccelerometerData!
    private var timeKnocks = [TimeInterval]()
    private var lastKnockOperation: TimeInterval = 0.0
    private var operationStarted = false
    
    private var lastJerk: Double?
    private var lastJerkTimestamp: TimeInterval?
    public var minJounce: Double = 1500.0
    public var minAcceptableJounce: Double = 1000.0
    public var minAccel: Double = 0.45
    public var shouldShowAccel = false
    public var shouldShowJerk = false
    public var shouldShowJounce = true
    
    weak var delegate: JounceKnockDelegate?
    public static let sharedInstance = JounceKnockDetectorWorker()
    
    private var motionManager = CMMotionManager()
    private var locationManager = CLLocationManager()
    
    private init() {
        motionManager.accelerometerUpdateInterval = 0.025
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startOperation() {
        locationManager.stopUpdatingLocation()
        locationManager.startUpdatingLocation()
        if let queue = OperationQueue.current {
            motionManager.startAccelerometerUpdates(to: queue) {[unowned self] (data, error) -> Void in
                self.accelerometerIteration(data: data!)
            }
        }
    }
    
    func stopOperation() {
        motionManager.stopAccelerometerUpdates()
        operationStarted = false
        locationManager.stopUpdatingLocation()
    }
    
    private func accelerometerIteration(data: CMAccelerometerData) {
        
        let currentTime = NSDate.timeIntervalSinceReferenceDate
        var isDoubleKnock = false
        
        if lastCapturedData == nil {
            lastCapturedData = data
            return
        }
        
        if timeKnocks.count > 0 {
            let lastKnockTime = timeKnocks[timeKnocks.count - 1]
            if currentTime - lastKnockTime > maximumTimeBetweenSingleKnocks {
                timeKnocks = [TimeInterval]()
                //delegate?.knockEventTimedOut()
                isDoubleKnock = false
            }
        }
        
        // Jerk = (a2 - a1) / (t2 - t1)
        let currentJerk = (lastCapturedData.acceleration.z - data.acceleration.z) / (lastCapturedData.timestamp - data.timestamp)
        
        // Jounce = (jerk2 - jerk1) / (t2 - t1)
        var currentJounce = 0.0
        if let lastJerk = lastJerk, let lastJerkTimestamp = lastJerkTimestamp {
            currentJounce = (lastJerk - currentJerk) / (lastJerkTimestamp - data.timestamp)
            if abs(currentJounce) > 600 && abs(currentJounce) < 1050 {
                
            }
        }
        
        if currentTime - lastKnockOperation > timeNeededBetweenKnockOperations {
            if !operationStarted {
                operationStarted = true
            }
            
            if currentJounce > minJounce {
                if timeKnocks.count > 0 {
                    let lastKnockTime = timeKnocks[timeKnocks.count - 1]
                    
                    if currentTime - lastKnockTime < maximumTimeBetweenSingleKnocks && currentTime - lastKnockTime > minimumTimeBetweenSingleKnocks {
                        if timeKnocks.count + 1 == numberOfKnocksNeeded {
                            isDoubleKnock = true
                            timeKnocks = [TimeInterval]()
                            lastKnockOperation = currentTime
                            operationStarted = false
                        } else {
                            timeKnocks.append(currentTime)
                        }
                    }
                } else {
                    if timeKnocks.count + 1 == numberOfKnocksNeeded {
                        isDoubleKnock = true
                        timeKnocks = [TimeInterval]()
                        lastKnockOperation = currentTime
                        operationStarted = false
                    } else {
                        timeKnocks.append(currentTime)
                    }
                }
            }
            
            delegate?.chartData(jounce: currentJounce, isDoubleKnock: isDoubleKnock)
            
            lastCapturedData = data
            lastJerk = currentJerk
            lastJerkTimestamp = data.timestamp
            isDoubleKnock = false
        }
    }
}
