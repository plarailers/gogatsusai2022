import processing.serial.*;
import java.util.Queue;
import java.util.ArrayDeque;
import java.util.Map;

// ESP32 や Arduino との通信をまとめる。
// シミュレーションモードを使うと接続が無くてもある程度動作確認できる。
class Communication {
  boolean simulationMode;
  HashMap<Integer, Integer> simulationSpeedMap;
  PApplet parent;
  HashMap<Integer, Serial> esp32Map;  // 複数の ESP32 と Bluetooth でつながっている。
  Serial arduino;  // Arduino と有線でつながっている。
  Queue<TrainSignal> trainSignalBuffer;
  Queue<Integer> sensorSignalBuffer;
  
  Communication(PApplet parent) {
    this.parent = parent;
    simulationMode = false;
    simulationSpeedMap = new HashMap();
    esp32Map = new HashMap();
    trainSignalBuffer = new ArrayDeque();
    sensorSignalBuffer = new ArrayDeque();
  }
  
  void setup() {
    String osName = System.getProperty("os.name");
    boolean isMac = osName.startsWith("Mac");
    boolean isWindows = osName.startsWith("Windows");
    if (simulationMode) {
      if (isMac) {
        simulationSpeedMap.put(0, 0);
        simulationSpeedMap.put(1, 0);
        arduino = new Serial(parent, "/dev/tty.usbmodem14301", 9600);
      }
      if (isWindows) {
        simulationSpeedMap.put(0, 0);
        simulationSpeedMap.put(1, 0);
        arduino = new Serial(parent, "COM7", 9600);
      }
    } else {
      if (isMac) {
        esp32Map.put(0, new Serial(parent, "/dev/cu.ESP32-ESP32SPP", 115200));
        arduino = new Serial(parent, "/dev/tty.usbmodem14301", 9600);
      }
      if (isWindows) {
        esp32Map.put(0, new Serial(parent, "COM12", 115200));  // Dr.
        esp32Map.put(1, new Serial(parent, "COM8", 115200));  // E6
        arduino = new Serial(parent, "COM7", 9600);
      }
    }
    update();
  }
  
  void update() {
    if (simulationMode) {
      for (Map.Entry<Integer, Integer> entry : simulationSpeedMap.entrySet()) {
        int trainId = entry.getKey();
        int speed = entry.getValue();
        if (speed > 0) {
          trainSignalBuffer.add(new TrainSignal(trainId));
        }
      }
      if (arduino != null) {
        while (arduino.available() > 0) {
          sensorSignalBuffer.add(arduino.read());
        }
      }
    } else {
      for (Map.Entry<Integer, Serial> entry : esp32Map.entrySet()) {
        int trainId = entry.getKey();
        Serial esp32 = entry.getValue();
        if (esp32 != null) {
          // 同時刻に複数の信号が来る不具合のため、１回のループですべて消費する。
          if (esp32.available() > 0) {
            trainSignalBuffer.add(new TrainSignal(trainId));
            while (esp32.available() > 0) esp32.read();
          }
        }
      }
      if (arduino != null) {
        while (arduino.available() > 0) {
          sensorSignalBuffer.add(arduino.read());
        }
      }
    }
  }
  
  int availableTrainSignal() {
    return trainSignalBuffer.size();
  }
  
  TrainSignal receiveTrainSignal() {
    return trainSignalBuffer.remove();
  }
  
  int availableSensorSignal() {
    return sensorSignalBuffer.size();
  }
  
  int receiveSensorSignal() {
    return sensorSignalBuffer.remove();
  }
  
  // 指定した車両にinputを送る。
  void sendInput(int trainId, int input) {
    if (simulationMode) {
      simulationSpeedMap.put(trainId, input);
    } else {
      Serial esp32 = esp32Map.get(trainId);
      if (esp32 != null) {
        esp32.write(input);
      }
    }
  }
  
  // 指定したポイントに切替命令を送る。
  void sendToggle(int servoId, ServoState servoState) {
    if (arduino != null) {
      int servoStateCode = 0;
      switch (servoState) {
        case NoServo:
          return;
        case Straight:
          servoStateCode = 0;
          break;
        case Curve:
          servoStateCode = 1;
          break;
      }
      arduino.write(servoId);
      arduino.write(servoStateCode);
    }
  }
}

class TrainSignal {
  int trainId;
  TrainSignal(int trainId) {
    this.trainId = trainId;
  }
}
