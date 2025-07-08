import '../../zebra_printer.dart';
import 'check_connection_command.dart';
import 'get_detailed_printer_status_command.dart';
import 'get_head_status_command.dart';
import 'get_host_status_command.dart';
import 'get_language_command.dart';
import 'get_media_status_command.dart';
import 'get_pause_status_command.dart';
import 'get_printer_status_command.dart';
import 'get_setting_command.dart';
import 'send_calibration_command.dart';
import 'send_clear_alerts_command.dart';
import 'send_clear_buffer_command.dart';
import 'send_clear_errors_command.dart';
import 'send_command_command.dart';
import 'send_cpcl_clear_buffer_command.dart';
import 'send_cpcl_clear_errors_command.dart';
import 'send_cpcl_flush_buffer_command.dart';
import 'send_flush_buffer_command.dart';
import 'send_set_cpcl_mode_command.dart';
import 'send_set_zpl_mode_command.dart';
import 'send_unpause_command.dart';
import 'send_zpl_clear_buffer_command.dart';
import 'send_zpl_clear_errors_command.dart';
import 'send_zpl_flush_buffer_command.dart';

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
  
  /// Creates a SendClearErrorsCommand for clearing printer errors (generic)
  static SendClearErrorsCommand createSendClearErrorsCommand(
    ZebraPrinter printer,
  ) => SendClearErrorsCommand(printer);

  /// Creates a SendZplClearErrorsCommand for clearing printer errors (ZPL-specific)
  static SendZplClearErrorsCommand createSendZplClearErrorsCommand(
    ZebraPrinter printer,
  ) =>
      SendZplClearErrorsCommand(printer);

  /// Creates a SendCpclClearErrorsCommand for clearing printer errors (CPCL-specific)
  static SendCpclClearErrorsCommand createSendCpclClearErrorsCommand(
    ZebraPrinter printer,
  ) =>
      SendCpclClearErrorsCommand(printer);
  
  /// Creates a SendCalibrationCommand for calibrating the printer
  static SendCalibrationCommand createSendCalibrationCommand(
    ZebraPrinter printer,
  ) => SendCalibrationCommand(printer);
  
  /// Creates a SendClearBufferCommand for clearing the print buffer (generic)
  static SendClearBufferCommand createSendClearBufferCommand(
    ZebraPrinter printer,
  ) => SendClearBufferCommand(printer);
  
  /// Creates a SendZplClearBufferCommand for clearing the print buffer (ZPL-specific)
  static SendZplClearBufferCommand createSendZplClearBufferCommand(
    ZebraPrinter printer,
  ) =>
      SendZplClearBufferCommand(printer);

  /// Creates a SendCpclClearBufferCommand for clearing the print buffer (CPCL-specific)
  static SendCpclClearBufferCommand createSendCpclClearBufferCommand(
    ZebraPrinter printer,
  ) =>
      SendCpclClearBufferCommand(printer);

  /// Creates a SendFlushBufferCommand for flushing the print buffer (generic)
  static SendFlushBufferCommand createSendFlushBufferCommand(
    ZebraPrinter printer,
  ) => SendFlushBufferCommand(printer);
  
  /// Creates a SendZplFlushBufferCommand for flushing the print buffer (ZPL-specific)
  static SendZplFlushBufferCommand createSendZplFlushBufferCommand(
    ZebraPrinter printer,
  ) =>
      SendZplFlushBufferCommand(printer);

  /// Creates a SendCpclFlushBufferCommand for flushing the print buffer (CPCL-specific)
  static SendCpclFlushBufferCommand createSendCpclFlushBufferCommand(
    ZebraPrinter printer,
  ) =>
      SendCpclFlushBufferCommand(printer);

  /// Creates a SendSetZplModeCommand for setting printer to ZPL mode
  static SendSetZplModeCommand createSendSetZplModeCommand(
    ZebraPrinter printer,
  ) =>
      SendSetZplModeCommand(printer);

  /// Creates a SendSetCpclModeCommand for setting printer to CPCL mode
  static SendSetCpclModeCommand createSendSetCpclModeCommand(
    ZebraPrinter printer,
  ) =>
      SendSetCpclModeCommand(printer);

  /// Creates a SendClearAlertsCommand for clearing all printer alerts
  static SendClearAlertsCommand createSendClearAlertsCommand(
    ZebraPrinter printer,
  ) =>
      SendClearAlertsCommand(printer);

  /// Creates a GetPrinterStatusCommand for getting basic printer status
  static GetPrinterStatusCommand createGetPrinterStatusCommand(
    ZebraPrinter printer,
  ) =>
      GetPrinterStatusCommand(printer);

  /// Creates a GetDetailedPrinterStatusCommand for getting detailed printer status with recommendations
  static GetDetailedPrinterStatusCommand createGetDetailedPrinterStatusCommand(
    ZebraPrinter printer,
  ) =>
      GetDetailedPrinterStatusCommand(printer);
} 