import processing.serial.*;

// false: Disable PID. Keyboard input is directly sent to motor.
// true: Enable PID. Keyboard input should be speed command [cm/s] and input for motor is calculated by PID.
boolean USE_PID = false;

Serial myPort;  // Create object from Serial class
String inputText = "";
double speed_id = 0.0;

String getTime() {
  return String.format("%02d:%02d:%02d", hour(), minute(), second());
}

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
  println(getTime(), "Bluetooth connected");
}

void draw() {
  background(255);
  fill(0);
  textSize(100);
  textAlign(CENTER);
  text(inputText, width / 2, height / 2);
  while (myPort.available() > 0) {  // 車輪が1回転した信号が来たら
    int data = myPort.read();
    println(getTime(), "recieve", data);
    if (USE_PID == true) {
      int input = pidCalc(speed_id);  // comment out here to  pid計算
      myPort.write(input);
    }
  }
  if (USE_PID == true) {
    stopCheck();
  }
}

void sendSpeed(int tmp_speed) {
  if (USE_PID == true) {
    speed_id = speed_constrain(tmp_speed);
    println(getTime(), "send", speed_id);
    if (speed == 0.0) {  // 止まっているときは動かしてあげる
      int input = INPUT_START;
      println("input=INPUT_START");
      println(getTime(), "send", tmp_speed);
    }
  } else {
    myPort.write(tmp_speed);
    println(getTime(), "send", tmp_speed);
  }
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

int speed_constrain(int tmp_speed) {
  if (tmp_speed > 0) {
    return (int)(SPEED_MIN + (SPEED_MAX - SPEED_MIN) * tmp_speed/255);
  } else {
    return 0;
  }
}
