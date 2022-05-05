enum Status {
  Stopping,
  Running
};

// ---パラメータ---
double r = 1.4;  // 車輪の半径(cm)
double K_CAR = 1.0;  // 車両にinput=1を入れたときspeedいくつで動くか
int input = 0;
int INPUT_MIN = 40;  // 動き出すギリギリのinput
int INPUT_MAX = 255;
int INPUT_START = 50;  // 初動input
double SPEED_MIN = 10.0;  // 最低速度(cm/s)
double SPEED_MAX = 60.0;  // 最高速度(cm/s)
double kp = 0.3/K_CAR;
double ki = 0.1/K_CAR;
double kd = 0.01/K_CAR;

Status status = Status.Stopping;
int rotation_count = -1;  // stopされている状態からmoveが呼び出されてから何回転したか
double new_time = 0.0;  // 速度の偏差を取る際に使う。
double old_time = 0.0;  // 速度の偏差を取る際に使う。
double e0 = 0.0;  // 現在の偏差
double e1 = 0.0;  // 1つ前の偏差
double dt = 0.0;  // 微分時間、積分時間。単位(s)
double I = 0.0;  // 積分項
double speed = 0.0;

// PID制御でinputを計算する関数
int pidCalc(double speed_id) {
  if (speed_id == 0) {
    pidReset();
    return 0;
  } else {
    if((double)millis()/1000 - new_time < 0.05){
      println(getTime(), "[PID]", rotation_count, old_time, new_time, dt, speed, e1, e0, input);
      return input;
    }
    rotation_count += 1;
    old_time = new_time;
    new_time = (double)millis() / 1000;
    dt = new_time - old_time;
    if (dt == 0) {println("devide 0"); return INPUT_MIN;}
    speed = PI*r / dt;
    e1 = e0;
    e0 = speed_id - speed;

    if (rotation_count >= 2) {  // 2周目以降はe0が使える
      I += e0 * dt;
    }
    if (rotation_count <=20) {
      input = INPUT_START;  println(getTime(), "[PID] PID start");
    } else {  // 3周目以降はe0,e1が使える
      input = (int)(kp*e0 + ki*I + kd*(e0-e1)/dt)+ input;
    }
    input = min(input, INPUT_MAX);
    input = max(input, INPUT_MIN);
    println(getTime(), "[PID] rc oldt newt dt speed e1 e0 input");
    println(getTime(), "[PID]", rotation_count, old_time, new_time, dt, speed, e1, e0, input);
    return input;
  }
  
}

void stopCheck() {
  if (rotation_count > 0 && millis()/1000 - new_time > (PI*r)/SPEED_MIN) {
    pidReset();  // 最低速度以下の速度なら停止とみなし、もう一度始動を行う
  }
}

void pidReset() {
  rotation_count = -1;
  I = 0;
  speed = 0;
  println(getTime(), "[PID] Stopped. PID reset.");
  myPort.write(0);
}
