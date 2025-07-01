# Development Documentation

This section contains documentation for developers working on the Zebra Printer Utility plugin.

## Development Resources

### 📋 [Future Improvements](TODO.md)
Comprehensive roadmap and planned features for the plugin, including architectural improvements and code sharing strategies.

### 📝 [Changelog](CHANGELOG.md)
Complete history of changes, bug fixes, and new features across all versions of the plugin.

## Development Guidelines

### Architecture
- **Native Code**: Keep minimal, focus on platform-specific bridging
- **Dart Logic**: Move business logic to Dart for better code sharing
- **Error Handling**: Implement consistent error patterns across platforms
- **Testing**: Maintain comprehensive test coverage

### Code Organization
- **iOS**: Use Objective-C wrapper for ZSDK, Swift for business logic
- **Android**: Keep ZSDK integration minimal, focus on bridging
- **Dart**: Centralize printer operations, discovery, and connection management

### Contributing
1. Review the [Future Improvements](TODO.md) for current priorities
2. Follow the established architecture patterns
3. Add tests for new functionality
4. Update documentation as needed
5. Check the [Changelog](CHANGELOG.md) for recent changes

## Quick Links

- [Main Project README](../../README.md)
- [Example App Documentation](../example/README.md)
- [iOS Implementation](../ios/README.md)
- [Library Documentation](../lib/README.md) 