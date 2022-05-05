//esp32を使った有線テスト用。abcdで操作。

/*------------------------------------------*/
const int INPUT_PIN = A18; // モーターのピン
const int SENSOR_PIN = 4;  // ホールセンサーのピン
int INPUT_MAX = 255;  // inputの上限
int INPUT_MIN = 0;    // inputの下限
int input = 0;  // モータへの入力(0～255)
char v; //pcからの信号(a, b, c, d)
int sensor_value = LOW;
int prev_sensor_value = LOW;
/*---------------------------------------------*/

void setup() {
  Serial.begin(115200);
  pinMode(4, INPUT);
  //ledcSetup(0, 12800, 8);
  ledcSetup(0, 700, 8);
  ledcAttachPin(INPUT_PIN, 0);
}

void loop(){

//モータの接触不良を確認する
  if (Serial.available()>0) {
    v = Serial.read();
    Serial.print(v);
    if (v == 'a') {
      input = 60;
    }
    else if (v == 'b') {
      input = 0;
    }
    else if (v == 'c') {
      input += 10;
    }
    else if (v == 'd') {
      input -= 10;
    }
  }
  input = constrain(input, INPUT_MIN, INPUT_MAX);
  analogWrite(INPUT_PIN, input);
  Serial.print("input:");
  Serial.print(input);
  Serial.println(" ");

//ホールセンサの接触不良を確認する。
  sensor_value = digitalRead(SENSOR_PIN);
//  Serial.print("sensor_value:");
//  Serial.print(sensor_value);
//  Serial.println(" ");
}
