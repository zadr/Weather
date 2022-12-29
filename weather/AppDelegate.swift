import Cocoa
import CoreLocation
import WeatherKit

@globalActor
struct WeatherActor {
	actor ActorType {}
	static var shared: ActorType = ActorType()
}

@main
class AppDelegate : NSObject, CLLocationManagerDelegate, NSMenuDelegate, NSApplicationDelegate {
	@IBOutlet
	private var window: NSWindow!

	private var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
	private var manager = CLLocationManager()
	@NSCopying private var placemark: CLPlacemark? = nil
	private var currentWeatherData: Weather? = nil
	private var activeTimer: Timer? = nil

	func applicationWillFinishLaunching(_ notification: Notification) {
		manager.delegate = self
		manager.distanceFilter = 1000.0
		manager.desiredAccuracy = kCLLocationAccuracyKilometer
		manager.pausesLocationUpdatesAutomatically = false

		statusItem.button?.imagePosition = .imageLeft
		statusItem.button?.imageHugsTitle = true
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [unowned self] in
			manager.requestAlwaysAuthorization()
			manager.startUpdatingLocation()
		}
	}

	// MARK: -

	func menuWillOpen(_ menu: NSMenu) {
		statusItem.button?.image?.isTemplate = true
	}

	func menuDidClose(_ menu: NSMenu) {
		statusItem.button?.image?.isTemplate = false
	}

	// MARK: -

	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		manager.startUpdatingLocation()
		locationManager(manager, didUpdateLocations: [ manager.location ].compactMap { $0 })
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.last ?? manager.location else {
			return
		}

		Task {
			await fetchWeatherData(for: location)
			await geocode(location: location)
			await scheduleUpdate()
		}
	}

	// MARK: -

	@MainActor
	@objc func updateMenu() {
		Task {
			await fetchWeatherData(for: manager.location)
			scheduleUpdate()
		}
	}

	@MainActor
	func buildMenuWithCurrentWeatherData(weather: Weather?, placemark: CLPlacemark?) {
		guard let weather else {
			return
		}

		statusItem.button?.image = NSImage(systemSymbolName: weather.currentWeather.symbolName, accessibilityDescription: weather.currentWeather.condition.rawValue)

		let measurementFormatter = MeasurementFormatter()
		statusItem.button?.title = String(format: " %@° and %@", measurementFormatter.string(from:  weather.currentWeather.temperature), weather.currentWeather.condition.rawValue).lowercased()

		let menu = NSMenu()
		menu.delegate = self

		var addSeparator = true
		if let placemark {
			if let areaOfInterest = placemark.areasOfInterest?.first, !areaOfInterest.isEmpty {
				menu.addItem(withTitle: areaOfInterest, action: nil, keyEquivalent: "")
			} else if let subLocality = placemark.subLocality, !subLocality.isEmpty {
				menu.addItem(withTitle: subLocality, action: nil, keyEquivalent: "")
			} else if let locality = placemark.locality, !locality.isEmpty {
				menu.addItem(withTitle: locality, action: nil, keyEquivalent: "")
			} else if let subAdministrativeArea = placemark.subAdministrativeArea, !subAdministrativeArea.isEmpty {
				menu.addItem(withTitle: subAdministrativeArea, action: nil, keyEquivalent: "")
			} else if let subAdministrativeArea = placemark.subAdministrativeArea, !subAdministrativeArea.isEmpty {
				menu.addItem(withTitle: subAdministrativeArea, action: nil, keyEquivalent: "")
			} else if let postalCode = placemark.postalCode, !postalCode.isEmpty {
				menu.addItem(withTitle: postalCode, action: nil, keyEquivalent: "")
			} else {
				addSeparator = false
			}
		}

		if addSeparator {
			menu.addItem(.separator())
		}

		let formatter = DateFormatter()
		formatter.formattingContext = .listItem
		formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hh a", options: 0, locale: .autoupdatingCurrent)

		let hhmmFormatter = DateFormatter()
		hhmmFormatter.formattingContext = .listItem
		hhmmFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hh: mm a", options: 0, locale: .autoupdatingCurrent)

		var menuItemsByTimestamp = [Date: NSMenuItem]()

		// add all hourly forecasts
		for forecast in weather.hourlyForecast {
			let time = formatter.string(from: forecast.date).lowercased()
			let title = String(format: "%@: %.0f° and %@", time, measurementFormatter.string(from:  forecast.temperature), forecast.condition.rawValue).lowercased()
			let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
			item.representedObject = forecast

			menuItemsByTimestamp[forecast.date] = item
		 }

		// add any upcoming sunrises or sunsets
		for forecast in weather.dailyForecast {
			if let sunrise = forecast.sun.sunrise {
				let sunriseTitle = String(format: "Sunrise ↑ %@", hhmmFormatter.string(from: sunrise).lowercased())
				let sunriseItem = NSMenuItem(title: sunriseTitle, action: nil, keyEquivalent: "")
				sunriseItem.representedObject = forecast

				menuItemsByTimestamp[sunrise] = sunriseItem
			}

			if let sunset = forecast.sun.sunset {
				let sunsetTitle = String(format: "Sunset ↓ %@", hhmmFormatter.string(from: sunset).lowercased())
				let sunsetItem = NSMenuItem(title: sunsetTitle, action: nil, keyEquivalent: "")
				sunsetItem.representedObject = forecast

				menuItemsByTimestamp[sunset] = sunsetItem
			}
		 }

		let fifteenMinutesAgo = Date(timeIntervalSinceNow: -15 * 60)

		var previousKey: Date? = nil
		for key in menuItemsByTimestamp.keys.sorted(by: { x, y in x > y }) {
			if fifteenMinutesAgo > key {
				continue
			}

			// always show the first item + show any other item that is an hourly forecast, or on a timestamp between two hourly forecasts
			if previousKey == nil || key.timeIntervalSince(previousKey!) <= 3600 {
				previousKey = key

				menu.addItem(menuItemsByTimestamp[key]!)
			}
		 }

		menu.addItem(.separator())
		menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

		statusItem.menu = menu
	}

	// MARK: -

	@WeatherActor
	func fetchWeatherData(for location: CLLocation?) async {
		guard let location else { return }

		let weather = try? await WeatherService.shared.weather(for: location)
		self.currentWeatherData = weather

		Task {
			await self.buildMenuWithCurrentWeatherData(weather: weather, placemark: placemark)
		}
	}

	@WeatherActor
	func geocode(location: CLLocation?) {
		guard let location else { return }

		CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
			DispatchQueue.main.async { [unowned self] in
				placemark = placemarks?.first

				buildMenuWithCurrentWeatherData(weather: currentWeatherData, placemark: placemark)
			}
		}
	}

	// MARK: -

	@MainActor
	func scheduleUpdate() {
		activeTimer?.invalidate()

		var plusOneHour = DateComponents()
		plusOneHour.hour = 1

		let nextPlusAnHour = Calendar.current.date(byAdding: plusOneHour, to: .now)!
		let nextPlusAnHourComponents = Calendar.current.dateComponents([ .month, .year, .hour ], from: nextPlusAnHour)
		let next = Calendar.current.date(from: nextPlusAnHourComponents)!

		activeTimer = Timer.scheduledTimer(timeInterval: next.timeIntervalSinceNow, target: self, selector: #selector(updateMenu), userInfo: nil, repeats: false)
	}
}
