## [0.1.0] - Current Development Version

**Note**: Version is automatically incremented on every commit using semantic versioning.

### Version Strategy
- Major version (1.x.x): Breaking API changes
- Minor version (x.1.x): New features, backward compatible
- Patch version (x.x.1): Bug fixes, backward compatible

## [Unreleased]
* **BREAKING**: Implemented comprehensive Result<T> pattern for all action methods
  - All methods now return Result<T> instead of bool/throwing exceptions
  - Added detailed error information with error codes, messages, and stack traces
  - Enhanced PrinterReadiness with nullable properties for unchecked statuses
  - Added new error codes: NO_PRINTERS_FOUND, MULTIPLE_PRINTERS_FOUND, OPERATION_ERROR
* iOS bi-directional communication support with `getSetting` and `sendDataWithResponse` methods
* Enhanced autoPrint functionality that only works with paired Bluetooth printers  
* Real printer status checks using SGD commands (media.status, head.latch, device.pause, device.host_status)
* Improved operation queue with proper async/await semantics
* Fixed threading issue in iOS discovery callbacks that could cause crashes
* AutoPrint now requires paired Bluetooth printers for predictable behavior
* Operation queue processing is now truly asynchronous
* Discovery callbacks on iOS now properly dispatch to main thread

## 0.0.39
Updated native code.

## 0.0.38
Fix bug in getting instance.
Improve performance for request local network.

## 0.0.34
Request access for local network in ios.


## 0.0.40
Upgrade dependencies 
Enhance code quality and eliminate unnecessary code.

## 0.0.41
Include ZebraUtilPlugin.java in the repository.

## 0.1.41 
Avoid duplicate devices.
Improve list devices example.

## 0.2.41
Update view based on printer state.

## 0.3.41
Dynamically disconnect the current printer when the user selects a different one.
Change the color and update the state once the printer is disconnected.

## 1.3.41
* Automatic Bluetooth Device Scanning:

Implemented continuous scanning for nearby Bluetooth devices to improve device discovery without manual intervention.
Added background listening for Bluetooth device connections and disconnections, ensuring real-time updates for device availability.

* Code Quality Enhancements:

Refactored Bluetooth scanning logic to optimize memory usage and prevent potential memory leaks.
Improved thread management to prevent excessive thread creation during Bluetooth operations.
Applied coding best practices, including proper resource management and context handling, to improve maintainability and performance.

## 1.4.41
* Support Spanish language.
* Synchronize printer once the scan has been restarted.

## 1.4.42
* Fix error in Printer class, devices were duplicated.
* Persist printer connected.