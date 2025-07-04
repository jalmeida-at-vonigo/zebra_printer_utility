import '../../zebra_printer.dart';
import 'check_connection_command.dart';
import 'get_head_status_command.dart';
import 'get_host_status_command.dart';
import 'get_language_command.dart';
import 'get_media_status_command.dart';
import 'get_pause_status_command.dart';
import 'get_setting_command.dart';
import 'send_calibration_command.dart';
import 'send_clear_buffer_command.dart';
import 'send_clear_errors_command.dart';
import 'send_command_command.dart';
import 'send_flush_buffer_command.dart';
import 'send_unpause_command.dart';

/// Factory class for creating printer command instances
class CommandFactory {
  /// Creates a GetSettingCommand for retrieving any printer setting
  static GetSettingCommand createGetSettingCommand(
    ZebraPrinter printer,
    String setting,
  ) => GetSettingCommand(printer, setting);
  
  /// Creates a SendCommandCommand for sending any command to the printer
  static SendCommandCommand createSendCommandCommand(
    ZebraPrinter printer,
    String command,
  ) => SendCommandCommand(printer, command);
  
  /// Creates a CheckConnectionCommand for checking printer connection
  static CheckConnectionCommand createCheckConnectionCommand(
    ZebraPrinter printer,
  ) => CheckConnectionCommand(printer);
  
  /// Creates a GetMediaStatusCommand for getting media status
  static GetMediaStatusCommand createGetMediaStatusCommand(
    ZebraPrinter printer,
  ) => GetMediaStatusCommand(printer);
  
  /// Creates a GetHeadStatusCommand for getting head status
  static GetHeadStatusCommand createGetHeadStatusCommand(
    ZebraPrinter printer,
  ) => GetHeadStatusCommand(printer);
  
  /// Creates a GetPauseStatusCommand for getting pause status
  static GetPauseStatusCommand createGetPauseStatusCommand(
    ZebraPrinter printer,
  ) => GetPauseStatusCommand(printer);
  
  /// Creates a GetHostStatusCommand for getting host status
  static GetHostStatusCommand createGetHostStatusCommand(
    ZebraPrinter printer,
  ) => GetHostStatusCommand(printer);
  
  /// Creates a GetLanguageCommand for getting printer language
  static GetLanguageCommand createGetLanguageCommand(
    ZebraPrinter printer,
  ) => GetLanguageCommand(printer);
  
  /// Creates a SendUnpauseCommand for unpausing the printer
  static SendUnpauseCommand createSendUnpauseCommand(
    ZebraPrinter printer,
  ) => SendUnpauseCommand(printer);
  
  /// Creates a SendClearErrorsCommand for clearing printer errors
  static SendClearErrorsCommand createSendClearErrorsCommand(
    ZebraPrinter printer,
  ) => SendClearErrorsCommand(printer);
  
  /// Creates a SendCalibrationCommand for calibrating the printer
  static SendCalibrationCommand createSendCalibrationCommand(
    ZebraPrinter printer,
  ) => SendCalibrationCommand(printer);
  
  /// Creates a SendClearBufferCommand for clearing the print buffer
  static SendClearBufferCommand createSendClearBufferCommand(
    ZebraPrinter printer,
  ) => SendClearBufferCommand(printer);
  
  /// Creates a SendFlushBufferCommand for flushing the print buffer
  static SendFlushBufferCommand createSendFlushBufferCommand(
    ZebraPrinter printer,
  ) => SendFlushBufferCommand(printer);
} 