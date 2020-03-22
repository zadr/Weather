#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef NS_ENUM(NSUInteger, WMWeatherDescriptionType) {
	WMConditionNotAvailable,
	WMConditionTornado,
	WMConditionTropicalStorm,
	WMConditionHurricane,
	WMConditionSevereThunderstorms,
	WMConditionThunderstorms,
	WMConditionMixedRainAndSnow,
	WMConditionMixedRainAndSleet,
	WMConditionMixedSnowAndSleet,
	WMConditionFreezingDrizzle,
	WMConditionDrizzle,
	WMConditionFreezingRain,
	WMConditionShowers,
	WMConditionSnowFlurries,
	WMConditionLightSnowShowers,
	WMConditionBlowingSnow,
	WMConditionSnow,
	WMConditionHail,
	WMConditionSleet,
	WMConditionDust,
	WMConditionFoggy,
	WMConditionHaze,
	WMConditionSmoky,
	WMConditionBlustery,
	WMConditionWindy,
	WMConditionCold,
	WMConditionCloudy,
	WMConditionMostlyCloudyNight,
	WMConditionMostlyCloudyDay,
	WMConditionPartlyCloudyNight,
	WMConditionPartlyCloudyDay,
	WMConditionClearNight,
	WMConditionSunny,
	WMConditionFairNight,
	WMConditionFairDay,
	WMConditionMixedRainAndHail,
	WMConditionHot,
	WMConditionIsolatedThunderstorms,
	WMConditionScatteredThunderstorms,
	WMConditionScatteredShowers,
	WMConditionHeavySnow,
	WMConditionScatteredSnowShowers,
	WMConditionPartlyCloudy,
	WMConditionSnowShowers,
	WMConditionIsolatedThundershowers,
};

@interface WMTypes : NSObject
+ (WMWeatherDescriptionType) primaryConditionForRange:(NSRange) range inHourlyForecasts:(NSArray *) forecasts;
+ (NSArray *) WeatherDescriptions;
@end

@interface NSColor (WMAdditions)
+ (NSColor *) calColorFromString:(NSString *) arg1;
- (NSString *) calStringRepresentation;
@end

#pragma mark -

@protocol WMDataWithDate <NSObject>
@required
@property (copy, readonly) NSDate *creationDate;
@end

@interface WMObject : NSObject
+ (id) knownKeys;
- (NSString *) summary;
- (NSString *) summaryThatIsCompact:(BOOL) compact;
@end

#pragma mark -

@interface WMLocation : WMObject <NSSecureCoding, NSCopying, WMDataWithDate>
@property (readonly) NSInteger woeid;
@property (readonly, copy) NSTimeZone *timeZone;
@property (readonly, copy) NSString *locationID;
@property (readonly, copy) CLLocation *geoLocation;
@property (readonly, copy) NSString *countryAbbreviation;
@property (readonly, copy) NSString *country;
@property (readonly, copy) NSString *stateAbbreviation;
@property (readonly, copy) NSString *state;
@property (readonly, copy) NSString *county;
@property (readonly, copy) NSString *city;
@end

#pragma mark -

@interface WMWeatherData : WMObject <NSSecureCoding, NSCopying, WMDataWithDate>
+ (NSString *) temperatureUnitsBasedOnLocale;
+ (NSString *) temperatureStringBasedOnLocaleGivenCelsius:(CGFloat) celsius fahrenheit:(CGFloat) fahrenheit;
+ (CGFloat) temperatureBasedOnLocaleGivenCelsius:(CGFloat) celsius fahrenheit:(CGFloat) fahrenheit;
+ (CGFloat) temperatureInFahrenheitGivenCelsius:(CGFloat) fahrenheit;

@property (readonly, copy) NSString *naturalLanguageStringFahrenheit;
@property (readonly, copy) NSString *naturalLanguageStringCelsius;
@property (readonly, copy) NSDate *sunsetDate;
@property (readonly, copy) NSDate *sunriseDate;
@property (readonly) CGFloat chanceOfPrecipitation;
@property (readonly, copy) NSColor *temperatureHighColor;
@property (readonly, copy) NSColor *temperatureLowColor;
@property (readonly) CGFloat temperatureHighCelsius;
@property (readonly) CGFloat temperatureLowCelsius;
@property (readonly) CGFloat temperatureCelsius;
@property (readonly, copy) NSDate *creationDate;
@property (readonly, copy) NSURL *imageSmallURL;
@property (readonly, copy) NSURL *imageLargeURL;
@property (readonly, copy) NSString *conditionLocalizedString;
@property (readonly) NSUInteger conditionCode;
@property (readonly) CLLocationCoordinate2D coordinate;
@property (readonly, copy) WMLocation *location;
@property (readonly, copy) NSDateComponents *representedDate;
@property (readonly) WMWeatherDescriptionType weatherDataType;
@property (readonly, copy) NSString *temperatureStringHighLowBasedOnLocale;
@property (readonly, copy) NSString *temperatureStringHighBasedOnLocale;
@property (readonly, copy) NSString *temperatureStringLowBasedOnLocale;
@property (readonly, copy) NSString *temperatureStringBasedOnLocale;
@property (readonly) CGFloat temperatureHighBasedOnLocale;
@property (readonly) CGFloat temperatureLowBasedOnLocale;
@property (readonly) CGFloat temperatureBasedOnLocale;
@property (readonly) CGFloat temperatureHighFahrenheit;
@property (readonly) CGFloat temperatureLowFahrenheit;
@property (readonly) CGFloat temperatureFahrenheit;

- (NSString *) naturalLanguageString:(BOOL) basedOnLocale;
@end

#pragma mark -

@protocol WMWeatherStoreProtocol <NSObject>
@required
- (void) currentConditionsForCoordinate:(CLLocationCoordinate2D) coordinate result:(void (^)(WMWeatherData *currentConditions)) result;
- (void) currentHourlyForecastForCoordinate:(CLLocationCoordinate2D) coordinate result:(void (^)(NSArray <WMWeatherData *> *hourlyForecasts)) result;
- (void) currentDailyForecastForCoordinate:(CLLocationCoordinate2D) coordinate result:(void (^)(NSArray <WMWeatherData *> *dailyForecast)) result;
- (void) forecastForCoordinate:(CLLocationCoordinate2D) coordinate atDate:(NSDateComponents *) components result:(void (^)(WMWeatherData *forecast)) result;
- (void) historicalWeatherForCoordinate:(CLLocationCoordinate2D) coordinate atDate:(NSDateComponents *) components result:(void (^)(WMWeatherData *historicalWeather)) result;
- (void) almanacWeatherForCoordinate:(CLLocationCoordinate2D) coordinate atDate:(NSDateComponents *) components result:(void (^)(WMWeatherData *almanacWeather)) result;
- (void) weatherForCoordinate:(CLLocationCoordinate2D) coordinate atDate:(NSDateComponents *) components result:(void (^)(WMWeatherData *weather)) result;
@end

@interface WMWeatherStore : NSObject <WMWeatherStoreProtocol>
+ (WMWeatherStore *) sharedWeatherStore;

@property (readonly, retain) id <WMWeatherStoreProtocol> remoteWeatherStore;
@property (readonly, retain) NSXPCConnection *connection;
@end
