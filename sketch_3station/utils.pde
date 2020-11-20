import java.io.InputStreamReader;
import java.util.Map;

class Device {
  String address;
  String name;
  String port;
  
  Device(String address, String name, String port) {
    this.address = address;
    this.name = name;
    this.port = port;
  }
}

class BluetoothDevice extends Device {
  BluetoothDevice(String address, String name, String port) {
    super(address, name, port);
  }
  
  String toString() {
    return "BluetoothDevice(address: " + address + ", name: " + name + ", port: " + port + ")";
  }
}

ArrayList<BluetoothDevice> discoverBluetoothDevicesForWindows() {
  ArrayList<BluetoothDevice> devices = new ArrayList();
  try {
    Runtime r = Runtime.getRuntime();
    Process p;
    BufferedReader br;
    HashMap<String, String> hm = new HashMap();
    p = r.exec("REG QUERY HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\BTHENUM /s /v FriendlyName");
    br = new BufferedReader(new InputStreamReader(p.getInputStream()));
    while (true) {
      String s = br.readLine();
      if (s == null) break;
      String key = "BluetoothDevice_";
      int idx = s.indexOf(key);
      if (idx != -1) {
        String address = s.substring(idx + key.length());
        s = br.readLine();
        String name = s.substring("    FriendlyName    REG_SZ    ".length());
        hm.put(address, name);
      }
    }
    p = r.exec("REG QUERY HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\BTHENUM /s /v PortName");
    br = new BufferedReader(new InputStreamReader(p.getInputStream()));
    while (true) {
      String s = br.readLine();
      if (s == null) break;
      for (Map.Entry<String, String> entry : hm.entrySet()) {
        String address = entry.getKey();
        String name = entry.getValue();
        if (s.contains(address)) {
          s = br.readLine();
          String port = s.substring("    PortName    REG_SZ    ".length());
          devices.add(new BluetoothDevice(address, name, port));
        }
      }
    }
  } catch (IOException e) {
    e.printStackTrace();
  }
  return devices;
}

class USBDevice extends Device {
  USBDevice(String address, String name, String port) {
    super(address, name, port);
  }
  
  String toString() {
    return "USBDevice(address: " + address + ", name: " + name + ", port: " + port + ")";
  }
}

ArrayList<USBDevice> discoverUSBDevicesForWindows() {
  ArrayList<USBDevice> devices = new ArrayList();
  try {
    Runtime r = Runtime.getRuntime();
    Process p;
    BufferedReader br;
    HashMap<String, String> hm = new HashMap();
    p = r.exec("REG QUERY HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\USB /s /v FriendlyName");
    br = new BufferedReader(new InputStreamReader(p.getInputStream()));
    while (true) {
      String s = br.readLine();
      if (s == null) break;
      if (s.startsWith("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\USB")) {
        String path = s;
        s = br.readLine();
        String name = s.substring("    FriendlyName    REG_SZ    ".length());
        hm.put(path, name);
      }
    }
    p = r.exec("REG QUERY HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Enum\\USB /s /v PortName");
    br = new BufferedReader(new InputStreamReader(p.getInputStream()));
    while (true) {
      String s = br.readLine();
      if (s == null) break;
      for (Map.Entry<String, String> entry : hm.entrySet()) {
        String path = entry.getKey();
        String name = entry.getValue();
        if (s.startsWith(path)) {
          s = br.readLine();
          String port = s.substring("    PortName    REG_SZ    ".length());
          devices.add(new USBDevice("", name, port));
        }
      }
    }
  } catch (IOException e) {
    e.printStackTrace();
  }
  return devices;
}
