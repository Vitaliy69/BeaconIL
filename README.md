# iOS Beacon Indoor Location

Application allows to determine indoor location by Bluetooth tags, supporting iBeacon technology. 

UUID is required for correct work and 3 beacons as a minimum. Exponential moving average algorithm is used for RSSI filtration. Application use trilateration with a nonlinear least squares optimizer based on Levenberg-Marquardt algorithm in 2D-space.

Application support iPhone/iPad with iOS 13.0 or latter with verticall orientation only, demonstrate CoreData/iCloud usage, application settings based on UserDefaults, SpriteKit framework and new UITableViewDiffableDataSource technology.

Checked in Xcode 12.4.

Available in AppStore: https://apps.apple.com/us/app/beacon-indoor-location/id1561643830
