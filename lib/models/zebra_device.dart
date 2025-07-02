import 'dart:convert';
import 'dart:ui' show Color;

List<ZebraDevice> zebraDevicesModelFromJson(String str) =>
    List<ZebraDevice>.from(
        json.decode(str).map((x) => ZebraDevice.fromJson(x)));

String zebraDevicesToJson(List<ZebraDevice> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

ZebraDevice zebraDeviceModelFromJson(String str) =>
    ZebraDevice.fromJson(jsonDecode(str));

class ZebraDevice {
  final String address;
  final String name;
  final String status;
  final bool isWifi;
  final Color color;
  final bool isConnected;

  ZebraDevice(
      {required this.address,
      required this.name,
      required this.isWifi,
      required this.status,
      this.isConnected = false,
      this.color = const Color.fromARGB(255, 255, 0, 0),
      });
      
  factory ZebraDevice.empty() =>
      ZebraDevice(address: "", name: "", isWifi: false, status: '');

  factory ZebraDevice.fromJson(Map<String, dynamic> json) => ZebraDevice(
      address: json["ipAddress"] ?? json["macAddress"] ?? "",
      name: json["name"] ?? "",
      isWifi: json["isWifi"] == null 
          ? false 
          : (json["isWifi"] is bool 
              ? json["isWifi"] 
              : json["isWifi"].toString() == "true"),
      isConnected: json["isConnected"] == null 
          ? false 
          : (json["isConnected"] is bool 
              ? json["isConnected"] 
              : json["isConnected"].toString() == "true"),
      status: json["status"] ?? "",
      color: json["color"] != null
          ? Color(json["color"] as int)
          : const Color.fromARGB(255, 255, 0, 0));

  Map<String, dynamic> toJson() => {
        "ipAddress": address,
        "name": name,
        "isWifi": isWifi,
        "status": status,
        "isConnected": isConnected,
        "color": color.value
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ZebraDevice && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'ZebraDevice($address, $name)';

  ZebraDevice copyWith({
    String? address,
    String? name,
    bool? isWifi,
    String? status,
    bool? isConnected,
    Color? color,
  }) {
    return ZebraDevice(
        address: address ?? this.address,
        name: name ?? this.name,
        isWifi: isWifi ?? this.isWifi,
        status: status ?? this.status,
        isConnected: isConnected ?? this.isConnected,
        color: color ?? this.color);
  }
}
