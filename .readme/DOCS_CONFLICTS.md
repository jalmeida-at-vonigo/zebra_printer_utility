# Documentation Conflicts and Ambiguities

This document tracks conflicts and ambiguities found during documentation reorganization.

## Resolved Conflicts

### 1. iOS Setup Instructions Duplication
**Conflict**: Info.plist configuration appears twice in `.readme/ios/README.md`
**Resolution**: Merged into single comprehensive setup section in `platforms/ios/setup.md`

### 2. CPCL Implementation Details
**Conflict**: CPCL examples scattered across multiple files
**Resolution**: Consolidated into `guides/printing-formats.md`

## Unresolved Ambiguities

### 1. Android Implementation Status
**Ambiguity**: Different files claim different levels of Android support:
- Main README says "Limited" support
- Library docs suggest full support
- No clear documentation on what exactly is missing

**Current State**: 
- Network printing works
- Bluetooth discovery exists but connection status unclear
- No bi-directional communication implemented

**Recommendation**: Complete Android implementation or clearly document limitations

### 2. Version Numbering
**Ambiguity**: Changelog shows versions like 1.4.42 but README shows 0.0.1
**Issue**: No clear current version or versioning strategy

### 3. Thread Safety Claims
**Ambiguity**: iOS docs claim "thread-safe operations" but:
- Discovery callbacks were not thread-safe (fixed in recent commit)
- No clear documentation on which operations are thread-safe

### 4. Printer Language Auto-Detection
**Ambiguity**: Multiple references to "automatic language detection" but:
- Implementation was removed from native code
- Dart implementation status unclear
- No documentation on how it actually works

## Documentation Gaps

### 1. Error Handling
- No comprehensive error code reference
- Inconsistent error handling patterns between platforms

### 2. Performance Guidelines
- No guidance on discovery timeout values
- No recommendations for print data size limits
- No connection pooling documentation

### 3. Testing
- Testing guide exists but lacks:
  - Unit test examples
  - Integration test setup
  - Mock printer setup 