# A macOS Weather Menu Bar App
![](screenshot.png)

## How It Works
Combine two parts WeatherKit, one part CoreLocation, and sprinkle on a dash of AppKit. Mix it all together with Xcode, and voila; got yourself an app.

## WeatherKit?
macOS ships with a private framework, WeatherKit.

Although headers and documentation aren't available for this framework, it is possible to re-create them through Objective-C runtime metadata (with the help of tools like [class-dump](https://github.com/nygard/class-dump) or [dsdump](https://github.com/DerekSelander/dsdump)).

After that, you can usually guess your way through APIs that don't require special entitlements.