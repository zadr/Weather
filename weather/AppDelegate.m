#import "AppDelegate.h"

#import "WeatherKit.h"

@interface AppDelegate () <CLLocationManagerDelegate, NSMenuDelegate>
@property (weak) IBOutlet NSWindow *window;
@property (strong) NSStatusItem *statusItem;

@property (strong) CLLocationManager *manager;
@property (copy) CLPlacemark *placemark;

@property (strong) WMWeatherData *currentWeatherData;
@property (copy) NSArray <WMWeatherData *> *hourlyForecastData;
@property (copy) NSArray <WMWeatherData *> *dailyForecastData;
@end

@implementation AppDelegate
- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	_manager = [[CLLocationManager alloc] init];
	_manager.delegate = self;
	_manager.distanceFilter = 1000.0;
	_manager.desiredAccuracy = kCLLocationAccuracyKilometer;
	[_manager startUpdatingLocation];

	_statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	_statusItem.button.imagePosition = NSImageLeft;
	_statusItem.button.imageHugsTitle = YES;
}

- (void) menuWillOpen:(NSMenu *) menu {
	self.statusItem.button.image.template = YES;
}

- (void) menuDidClose:(NSMenu *) menu {
	self.statusItem.button.image.template = NO;
}

- (void) buildMenuWithCurrentWeatherData:(WMWeatherData *) currentConditions hourlyForecast:(NSArray <WMWeatherData *> *) hourlyForecast dailyForecast:(NSArray <WMWeatherData *> *) dailyForecast placemark:(CLPlacemark *) placemark {
	if (!currentConditions) {
		return;
	}

	self.statusItem.button.image = [[NSImage alloc] initWithContentsOfURL:currentConditions.imageSmallURL.filePathURL];
	self.statusItem.button.title = [NSString stringWithFormat:@"%.0f°", currentConditions.temperatureBasedOnLocale];

	NSMenu *menu = [[NSMenu alloc] init];
	menu.delegate = self;

	BOOL addSeparator = YES;
	if (placemark.areasOfInterest.count) {
		[menu addItemWithTitle:placemark.areasOfInterest.firstObject action:NULL keyEquivalent:@""];
	} else if (placemark.subLocality.length) {
		[menu addItemWithTitle:placemark.subLocality action:NULL keyEquivalent:@""];
	} else if (placemark.locality.length) {
		[menu addItemWithTitle:placemark.locality action:NULL keyEquivalent:@""];
	} else if (placemark.subAdministrativeArea) {
		[menu addItemWithTitle:placemark.subAdministrativeArea action:NULL keyEquivalent:@""];
	} else if (placemark.subAdministrativeArea.length) {
		[menu addItemWithTitle:placemark.subAdministrativeArea action:NULL keyEquivalent:@""];
	} else if (placemark.postalCode.length) {
		[menu addItemWithTitle:placemark.postalCode action:NULL keyEquivalent:@""];
	} else {
		addSeparator = NO;
	}

	if (addSeparator) {
		[menu addItem:[NSMenuItem separatorItem]];
	}

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.formattingContext = NSFormattingContextListItem;
	formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"hh a" options:0 locale:[NSLocale autoupdatingCurrentLocale]];

	NSDateFormatter *hhmmFormatter = [[NSDateFormatter alloc] init];
	hhmmFormatter.formattingContext = NSFormattingContextListItem;
	hhmmFormatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"hh:mm a" options:0 locale:[NSLocale autoupdatingCurrentLocale]];

	BOOL isLookingForSunrise = NO;
	NSMutableArray <WMWeatherData *> *dailyForecasts = [dailyForecast mutableCopy];
	if (dailyForecasts.firstObject.sunsetDate && [[NSDate date] laterDate:dailyForecasts.firstObject.sunsetDate] != dailyForecasts.firstObject.sunsetDate) {
		[dailyForecasts removeObjectAtIndex:0];
		isLookingForSunrise = YES;
	}

	BOOL addedSunset = NO;
	for (WMWeatherData *forecast in hourlyForecast) {
		NSDate *representedDate = [[NSCalendar currentCalendar] dateFromComponents:forecast.representedDate];

		if (isLookingForSunrise && dailyForecasts.firstObject.sunriseDate && [representedDate earlierDate:dailyForecasts.firstObject.sunriseDate] == dailyForecasts.firstObject.sunriseDate) {
			isLookingForSunrise = NO;
			NSString *title = [NSString stringWithFormat:@"Sunrise ↑ %@", [hhmmFormatter stringFromDate:dailyForecasts.firstObject.sunriseDate].lowercaseString];
			[menu addItemWithTitle:title action:NULL keyEquivalent:@""].representedObject = dailyForecasts.firstObject;
		} else if (!isLookingForSunrise && dailyForecasts.firstObject.sunsetDate && [representedDate laterDate:dailyForecasts.firstObject.sunsetDate] == representedDate) {
			addedSunset = YES;
			isLookingForSunrise = YES;
			NSString *title = [NSString stringWithFormat:@"Sunset ↓ %@", [hhmmFormatter stringFromDate:dailyForecasts.firstObject.sunsetDate].lowercaseString];
			[menu addItemWithTitle:title action:NULL keyEquivalent:@""].representedObject = dailyForecasts.firstObject;
			[dailyForecasts removeObjectAtIndex:0];
		}

		NSString *time = [formatter stringFromDate:representedDate].lowercaseString;
		NSString *title = [NSString stringWithFormat:@"%@: %.0f° and %@", time, forecast.temperatureBasedOnLocale, forecast.conditionLocalizedString];
		[menu addItemWithTitle:title action:NULL keyEquivalent:@""].representedObject = forecast;
	}

	if (isLookingForSunrise && dailyForecasts.firstObject.sunriseDate) {
		NSString *title = [NSString stringWithFormat:@"Sunrise ↑ %@", [hhmmFormatter stringFromDate:dailyForecasts.firstObject.sunriseDate].lowercaseString];
		[menu addItemWithTitle:title action:NULL keyEquivalent:@""].representedObject = dailyForecasts.firstObject;
	} else if (!addedSunset && dailyForecasts.firstObject.sunsetDate) {
		NSString *title = [NSString stringWithFormat:@"Sunset ↓ %@", [hhmmFormatter stringFromDate:dailyForecasts.firstObject.sunsetDate].lowercaseString];
		[menu addItemWithTitle:title action:NULL keyEquivalent:@""].representedObject = dailyForecasts.firstObject;
	}

	[menu addItem:[NSMenuItem separatorItem]];
	[menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];

	self.statusItem.menu = menu;
}

- (void) fetchWeatherDataForLocation:(CLLocation *) location {
	[[WMWeatherStore sharedWeatherStore] currentDailyForecastForCoordinate:location.coordinate result:^(NSArray <WMWeatherData *> *results) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.dailyForecastData = results;

			[self buildMenuWithCurrentWeatherData:self.currentWeatherData hourlyForecast:self.hourlyForecastData dailyForecast:self.dailyForecastData placemark:self.placemark];
		});
	}];

	[[WMWeatherStore sharedWeatherStore] currentConditionsForCoordinate:location.coordinate result:^(WMWeatherData *result) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.currentWeatherData = result;

			[self buildMenuWithCurrentWeatherData:self.currentWeatherData hourlyForecast:self.hourlyForecastData dailyForecast:self.dailyForecastData placemark:self.placemark];
		});
	}];

	[[WMWeatherStore sharedWeatherStore] currentHourlyForecastForCoordinate:location.coordinate result:^(NSArray <WMWeatherData *> *results) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.hourlyForecastData = [results subarrayWithRange:NSMakeRange(1, results.count - 2)];

			[self buildMenuWithCurrentWeatherData:self.currentWeatherData hourlyForecast:self.hourlyForecastData dailyForecast:self.dailyForecastData placemark:self.placemark];
		});
	}];
}

- (void) geocodeLocation:(CLLocation *) location {
	[[[CLGeocoder alloc] init] reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * placemarks, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.placemark = placemarks.firstObject;

			[self buildMenuWithCurrentWeatherData:self.currentWeatherData hourlyForecast:self.hourlyForecastData dailyForecast:self.dailyForecastData placemark:self.placemark];
		});
	}];
}

- (void) locationManager:(CLLocationManager *) manager didUpdateLocations:(NSArray *) locations {
	[self fetchWeatherDataForLocation:locations.lastObject];
	[self geocodeLocation:locations.lastObject];

	NSDateComponents *plusOneHour = [[NSDateComponents alloc] init];
	plusOneHour.hour = 1;

	NSDate *nextPlusAnHour = [[NSCalendar currentCalendar] dateByAddingComponents:plusOneHour toDate:[NSDate date] options:NSCalendarMatchLast | NSCalendarMatchNextTime];
	NSDateComponents *nextPlusAnHourComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitHour fromDate:nextPlusAnHour];
	NSDate *next = [[NSCalendar currentCalendar] dateFromComponents:nextPlusAnHourComponents];

	[NSTimer scheduledTimerWithTimeInterval:next.timeIntervalSinceNow target:self selector:@selector(updateMenu) userInfo:nil repeats:NO];
}

- (void) updateMenu {
	[self fetchWeatherDataForLocation:self.manager.location];

	[NSTimer scheduledTimerWithTimeInterval:(60.0 * 60.0) target:self selector:@selector(updateMenu) userInfo:nil repeats:YES];
}
@end
