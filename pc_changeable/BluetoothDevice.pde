import java.io.InputStreamReader;
import java.util.Map;

class BluetoothDevice {
  String address;
  String name;
  String port;
  
  BluetoothDevice(String address, String name, String port) {
    this.address = address;
    this.name = name;
    this.port = port;
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