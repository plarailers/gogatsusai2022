#include <BluetoothSerial.h>
BluetoothSerial SerialBT;

/*------------------------------------------*/
const int INPUT_PIN = A18; // モーターのピンGPIO25
const int SENSOR_PIN = 4;  // ホールセンサーのピンGPIO4
int INPUT_MAX = 255;  // inputの上限
int INPUT_MIN = 0;    // inputの下限
int input = 0;  // モータへの入力(0～255)
int sensor_value = LOW;
int prev_sensor_value = LOW;
/*---------------------------------------------*/

void setup() {
  SerialBT.begin("ESP32-Dr.");
  ledcSetup(0, 700, 8);
  ledcAttachPin(INPUT_PIN, 0);
  Serial.begin(115200);
  pinMode(4, INPUT);
}

void loop(){
  // PCから送られてきたinputをモーターへ
  while (SerialBT.available() > 0) {
    input = SerialBT.read();
  }
  input = constrain(input, INPUT_MIN, INPUT_MAX);  // vの上限・下限を制限
  ledcWrite(0, input);

  // 1回転ごとにPCに信号を送る
  prev_sensor_value = sensor_value;
  sensor_value = digitalRead(SENSOR_PIN);
  if (prev_sensor_value == LOW && sensor_value == HIGH) {
    SerialBT.write('o');
    delay(3); //低速運転時のチャタリングを防止。
  }
}
