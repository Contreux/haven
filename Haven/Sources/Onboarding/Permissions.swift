import Foundation
import CoreLocation
import UserNotifications

@MainActor
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    private var cont: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    func request() async -> CLLocationCoordinate2D? {
        mgr.delegate = self
        mgr.requestWhenInUseAuthorization()
        return await withCheckedContinuation { c in
            cont = c
            mgr.requestLocation()
        }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        let coord = locs.first?.coordinate
        MainActor.assumeIsolated { cont?.resume(returning: coord); cont = nil }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { cont?.resume(returning: nil); cont = nil }
    }
}

enum Reminders {
    static func enable() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
    static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Haven"; content.body = "A quiet moment to log today."
        var dc = DateComponents(); dc.hour = hour; dc.minute = minute
        let req = UNNotificationRequest(identifier: "haven.daily", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        UNUserNotificationCenter.current().add(req)
    }
}
