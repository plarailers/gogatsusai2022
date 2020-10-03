State state;
Timetable timetable;
Display display;
Communication communication;


class pidPrams {
  // ---パラメータ---
  // 個々の車両によって変化させる。
  int id;  // trainId
  double r;  // 車輪の半径 [cm]
  int INPUT_MIN;  // 動き出すギリギリのinput
  int INPUT_MAX;
  int INPUT_START;  // 初動input
  double kp;
  double ki;
  double kd;

  pidPrams(int id, double r, int INPUT_MIN, int INPUT_MAX, int INPUT_START, double kp, double ki, double kd) {
    this.id = id;
    this.r = r;
    this.INPUT_MIN = INPUT_MIN;
    this.INPUT_MAX = INPUT_MAX;
    this.INPUT_START = INPUT_START;
    this.kp = kp;
    this.ki = ki;
    this.kd = kd;
  }
  pidPrams getById(int id) {
    for (pidPrams p : all) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }
}

void settings() {
  size(1000, 500);

}

void setup() {
  state = new State();
  timetable = new Timetable();
  display = new Display();
  display.setup();
  communication = new Communication(this);
  communication.simulationMode = false;
  communication.setup();
  while (communication.availableTrainSignal() > 0) {  // 各列車について行う
    TrainSignal trainSignal = communication.receiveTrainSignal();  // 列車id取得
    int id = trainSignal.trainId;
    state.trainList.get(id).id = id;  // 当該列車を取得
  }
}

int time = 0;

void draw() {
  communication.update();

  // 各車両について行う
  for (Train train : state.trainList) {
    int targetSpeed = getTargetSpeed(train);
    // MoveResult moveResult = state.trainList.get(train.id).move(targetSpeed);  // 適当な距離進ませる
    // timetableUpdate(train, moveResult);  // 時刻表を更新する
    communication.sendInput(train.id, targetSpeed);
    println(time + " SEND train=" + train.id + ", input=" + targetSpeed);
  }

  // 各ポイントについて行う
  for (Junction junction : state.junctionList) {
    if (junctionControl(junction)) {  // ポイントを切り替えるべきか判定
      ServoState toggleResult = junction.toggle();  // ポイントを切り替える
      if (junction.servoId > -1 && toggleResult != ServoState.NoServo) {
        communication.sendToggle(junction.servoId, toggleResult);
        println(time + " SEND servo=" + junction.servoId + ", toggle=" + toggleResult);
      }
    }
  }

  // 車両から進んだ距離を取得し、シミュレーションを更新する
  while (communication.availableTrainSignal() > 0) {
    TrainSignal trainSignal = communication.receiveTrainSignal();
    int id = trainSignal.trainId;
    Train train = state.trainList.get(id);
    double delta = pidPrams.getById(id).r;
    MoveResult moveResult = train.move(delta);
    println(time + " RECEIVE train=" + id + ", delta=" + delta);
    timetableUpdate(train, moveResult);
  }
  
  // センサ入力で車両の位置補正を行う
  // センサ入力があったときに関数 positionAdjust(sensorId) を呼んでください
  if (keyPressed == true) {  // (デバッグ用)キーを押したらセンサ0の位置補正
    println("keyPressed");
    positionAdjust(0);
  }
  
  while (communication.availableSensorSignal() > 0) {
    int sensorId = communication.receiveSensorSignal();
    println(time + " RECEIVE sensor=" + sensorId);
    positionAdjust(sensorId);
  }
  
  // 描画
  display.draw(state);
  
  try{  // 一定時間待つ
    Thread.sleep(200);
  } catch(InterruptedException ex){
    ex.printStackTrace();
  }
  time += 200;
    
}
