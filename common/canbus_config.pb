# Bus config consumed by /system_ext/bin/canhalconfigurator-aidl at boot.
# Default config path /etc/canbus_config.pb resolves to /system/etc/canbus_config.pb
# on Android. Schema:
#   hardware/interfaces/automotive/can/aidl/default/tools/configurator/proto/canbus_config.proto

buses: [
  {
    name: "CAN0"
    native { ifname: "can0" }
    bitrate: 250000
  }
]
