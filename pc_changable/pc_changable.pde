import processing.serial.*;

Serial myPort;  // Create object from Serial class
String inputText = "";

void setup() {
  size(600, 400);
  String osName = System.getProperty("os.name");
  boolean isMac = osName.startsWith("Mac");
  boolean isWindows = osName.startsWith("Windows");
  //Bluetoothのシリアルを選択
  if (isMac) {
    myPort = new Serial(this, "/dev/cu.ESP32-ESP32SPP", 115200);//Mac
    //myPort = new Serial(this, "/dev/cu.Bluetooth-Incoming-Port", 115200);//Macテスト用
  }
  if (isWindows) {
    // Bluetooth接続可能なデバイスを列挙
    ArrayList<BluetoothDevice> deviceList = discoverBluetoothDevicesForWindows();
    printArray(deviceList);
    for (BluetoothDevice device : deviceList) {
      if (device.name.equals("ESP32-Dr.")) {
        myPort = new Serial(this, device.port, 115200);
        break;
      }
    }
  }
  println(millis(), "Bluetooth connected");
}

void draw() {
  background(255);
  fill(0);
  textSize(100);
  textAlign(CENTER);
  text(inputText, width / 2, height / 2);
  while (myPort.available() > 0) {  // 車輪が1回転した信号が来たら
    int data = myPort.read();
    println(millis(), "recieve", data);
  }
}

void sendSpeed(int tmp_speed) {
  myPort.write(tmp_speed);
}

void keyPressed() {
  if (keyCode == RETURN || keyCode == ENTER) {
    sendSpeed(int(inputText));
    inputText = "";
  } else if (keyCode == BACKSPACE) {
    if (inputText.length() >= 1) {
      inputText = inputText.substring(0, inputText.length() - 1);
    }
  } else if ('0' <= key && key <= '9') {
    if (inputText.length() < 3) {
      inputText += key;
    }
  }
}
