# Development Documentation

This section contains documentation for developers working on the Zebra Printer Utility plugin.

## Development Resources



### 🏗️ [Architecture Improvements](ARCHITECTURE_IMPROVEMENTS.md)
Recent architecture improvements including iOS bi-directional communication, enhanced autoPrint functionality, and operation queue enhancements.

### 📝 [Changelog](CHANGELOG.md)
Complete history of changes, bug fixes, and new features across all versions of the plugin.

## Development Guidelines

### Architecture
- **Native Code**: Keep minimal, focus on platform-specific bridging
- **Dart Logic**: Move business logic to Dart for better code sharing
- **Error Handling**: Use centralized Result<T> pattern with ZebraErrorBridge
- **Testing**: Maintain comprehensive test coverage with no skipped tests
- **Commands**: All printer operations use CommandFactory pattern
- **Communication**: CommunicationPolicy handles connection assurance and retries

### Code Organization
- **iOS**: Use Objective-C wrapper for ZSDK, Swift for business logic
- **Android**: Keep ZSDK integration minimal, focus on bridging
- **Dart**: Centralize printer operations, discovery, and connection management

### Recent Improvements (v2.0.57-58)
- **Naming Standardization**: All connection methods use consistent `isPrinterConnected` naming
- **Error System Cleanup**: Removed 45+ unused error codes, enhanced error categorization
- **Testing Fixes**: All tests passing with proper mock implementations
- **Lint Compliance**: Zero lint/analysis issues

### Contributing
1. Review the recent changes and improvements
2. Follow the established architecture patterns
3. Add tests for new functionality
4. Update documentation as needed
5. Check the [Changelog](CHANGELOG.md) for recent changes

## Quick Links

- [Main Project README](../../README.md)
- [Example App Documentation](../example/README.md)
- [iOS Implementation](../ios/README.md)
- [Library Documentation](../lib/README.md) 