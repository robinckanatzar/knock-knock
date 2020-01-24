import UIKit
import Charts

class JounceViewController: UIViewController, ChartViewDelegate {
    
    // MARK: Outlets
    @IBOutlet weak var chartView: LineChartView!
    
    // MARK: Variables
    let knockDetectorWorker = JounceKnockDetectorWorker.sharedInstance
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    var i: Double = 1.0
    
    // MARK: Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        registerBackgroundTask()
        registerLocalNotification()
        registerApplicationObservers()
        
        knockDetectorWorker.delegate = self
        
        setupChart()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: Private Methods
    private func setupChart() {
        self.chartView.delegate = self
        
        let set_min_threshold: LineChartDataSet = LineChartDataSet(entries:[ChartDataEntry(x: Double(0), y: Double(0))], label: "Minimum Threshold")
        set_min_threshold.drawCirclesEnabled = false
        set_min_threshold.setColor(UIColor.orange)
        
        let set_single_knock: LineChartDataSet = LineChartDataSet(entries:[ChartDataEntry(x: Double(0), y: Double(0))], label: "Single Knock")
        set_single_knock.drawCirclesEnabled = true
        set_single_knock.setColor(UIColor.red)
        set_single_knock.lineWidth = 0.1
        set_single_knock.circleRadius = 2
        set_single_knock.circleHoleRadius = 0.5
        set_single_knock.setCircleColor(UIColor.red)
        
        let set_double_knock: LineChartDataSet = LineChartDataSet(entries:[ChartDataEntry(x: Double(0), y: Double(0))], label: "Double Knock")
        set_double_knock.drawCirclesEnabled = true
        set_double_knock.setColor(UIColor.green)
        set_double_knock.lineWidth = 0.1
        set_double_knock.circleRadius = 4
        set_double_knock.circleHoleRadius = 2
        set_double_knock.setCircleColor(UIColor.green)
        
        let set_jounce: LineChartDataSet = LineChartDataSet(entries:[ChartDataEntry(x: Double(0), y: Double(0))], label: "Jounce")
        set_jounce.drawCirclesEnabled = false
        set_jounce.setColor(UIColor.purple)

        self.chartView.data = LineChartData(dataSets: [set_min_threshold, set_single_knock, set_double_knock, set_jounce])
    }
    
    // MARK: Background, Notifications, State Changes
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            [unowned self] in
            self.endBackgroundTask()
        }
        assert(backgroundTask != UIBackgroundTaskIdentifier.invalid)
    }
    
    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskIdentifier.invalid
    }
    
    func registerLocalNotification() {
        UNUserNotificationCenter
            .current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                /*if granted == true && error == nil {
                    self.scheduleNotifications()
                    // We have permission!
                }*/
        }
    }
    
    func registerApplicationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func appDidEnteredBackground() {
        knockDetectorWorker.startOperation()
    }
    
    @objc func appDidBecomeActive() {
        knockDetectorWorker.stopOperation()
    }
}

extension JounceViewController: JounceKnockDelegate {
    func chartData(jounce: Double, isDoubleKnock: Bool) {
        
        // Minimum Threshold
        self.chartView.data?.addEntry(ChartDataEntry(x: self.i, y: self.knockDetectorWorker.minJounce), dataSetIndex: 0)
        
        // Single Knock
        if jounce > knockDetectorWorker.minJounce {
            self.chartView.data?.addEntry(ChartDataEntry(x: self.i, y: 0.0), dataSetIndex: 1)
        }
    
        // Double Knock
        if isDoubleKnock {
            self.chartView.data?.addEntry(ChartDataEntry(x: self.i, y: -0.2), dataSetIndex: 2)
            self.knockEventPerformed()
        }
        
        // Jounce
        if knockDetectorWorker.shouldShowJounce {
            self.chartView.data?.addEntry(ChartDataEntry(x: self.i, y: jounce), dataSetIndex: 3)
        }
        
        self.chartView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(1000))
        
        self.chartView.notifyDataSetChanged()
        self.chartView.moveViewToX(self.i)
        
        self.i = self.i + 1.0
    }
    
    func knockEventPerformed() {
        let content = UNMutableNotificationContent()
        content.title = "JOUNCE Knock Knock"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            guard error == nil else { return }
            print("KNOCK - Jounce")
        }
    }
}
