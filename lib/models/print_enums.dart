/// Media types supported by Zebra printers
enum EnumMediaType { Label, BlackMark, Journal }

/// Printer commands
enum Command { calibrate, mediaType, darkness }

/// Print format types
enum PrintFormat { ZPL, CPCL }
