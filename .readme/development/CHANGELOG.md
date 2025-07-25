
- iOS bi-directional communication support with `getSetting` and `sendDataWithResponse` methods
- Enhanced autoPrint functionality that only works with paired Bluetooth printers  
- Real printer status checks using SGD commands (media.status, head.latch, device.pause, device.host_status)
- Improved operation queue with proper async/await semantics
- Enhanced PrinterReadiness with nullable properties for unchecked statuses
- Detailed error information with error codes, messages, and stack traces

### Fixed
- Threading issue in iOS discovery callbacks that could cause crashes
- AutoPrint now requires paired Bluetooth printers for predictable behavior
- Operation queue processing is now truly asynchronous
- Discovery callbacks on iOS now properly dispatch to main thread

## Previous Versions

### 1.4.42
* Fix error in Printer class, devices were duplicated.
* Persist printer connected.

### 1.4.41
* Support Spanish language.
* Synchronize printer once the scan has been restarted.

### 1.3.41
* Automatic Bluetooth Device Scanning:
  - Implemented continuous scanning for nearby Bluetooth devices to improve device discovery without manual intervention.
  - Added background listening for Bluetooth device connections and disconnections, ensuring real-time updates for device availability.
* Code Quality Enhancements:
  - Refactored Bluetooth scanning logic to optimize memory usage and prevent potential memory leaks.
  - Improved thread management to prevent excessive thread creation during Bluetooth operations.
  - Applied coding best practices, including proper resource management and context handling, to improve maintainability and performance.

### 0.3.41
Dynamically disconnect the current printer when the user selects a different one.
Change the color and update the state once the printer is disconnected.

### 0.2.41
Update view based on printer state.

### 0.1.41 
Avoid duplicate devices.
Improve list devices example.

### 0.0.41
Include ZebraUtilPlugin.java in the repository.

### 0.0.40
Upgrade dependencies 
Enhance code quality and eliminate unnecessary code.

### 0.0.39
Updated native code.

### 0.0.38
Fix bug in getting instance.
Improve performance for request local network.

### 0.0.34
Request access for local network in ios.