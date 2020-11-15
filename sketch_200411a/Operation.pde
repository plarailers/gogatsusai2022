// --------------------------------------------------------------
// 列車制御に使う定数【ここは適切に書き換える】
static final int STOPMERGIN = 40;  // Junctionや先行列車の何cm手前で停止するか
static final int TRAINLENGTH = 43;  // 列車1編成の長さ
static final int MINSTOPTIME = 5;  // 最低停車時間
static final int MAXSPEED = 40;  // 車両の最高速度 (cm/s)
static final int LOOPTIME = 5;  // ダイヤを一周全部実施したら、何秒待って時刻をリセットする？
boolean finishFlag[] = {false, false};  // 車両の台数ぶんfalseを代入
// --------------------------------------------------------------

// 初期状態へ戻す関数
void resetAll() {
  for (int i = 0; i < finishFlag.length; i++) {
    finishFlag[i] = false;  // 全列車のfinishFlagをリセット
    communication.sendInput(i, 0);  // inputを0にする
  }
  for (int i = 0; i < LOOPTIME; i++) {  // LOOPTIMEだけ待機
    display.draw(state);
    try{
      Thread.sleep(1000);
    } catch(InterruptedException ex){
      ex.printStackTrace();
    }
    time += 1000;
  }
  time = -1000;  // リセット
  timetable.reset();
  int i = 0;
}
// 【時刻表更新】moveResultを受け取って、時刻表を更新する
void timetableUpdate(Train train, MoveResult moveResult) {
  Info currentInfo = timetable.getByTrainId(train.id);

  if (moveResult == MoveResult.PassedStation) {
    currentInfo.used = true;  // 到着済・通過済に変更
    
    if (currentInfo != null && currentInfo.isArrival()) {  // 到着処理
      println(time + " OPERATION train" + train.id + " が 駅" + currentInfo.stationId +" に到着" );
      Info nextInfo = timetable.getByTrainId(train.id);  // 次に実施すべき時刻(=出発)を取得
      if (nextInfo != null) {
        if (nextInfo.time < time/1000 + MINSTOPTIME) {  // 遅れて到着した場合、最低停車時間だけは止まるように出発時刻情報を書き換える
          nextInfo.time = time/1000 + MINSTOPTIME;
          println(time + " OPERATION train" + train.id + " は遅れて駅" + currentInfo.stationId + "に到着したため、出発時刻を"+ (time/1000+MINSTOPTIME)+ "に繰り下げました");
        } 
      } else {  // ダイヤを全部こなして運転を終了した場合
        finishFlag[train.id] = true;
      }
      
    } else if (currentInfo != null && currentInfo.isPassage()) {  // 通過処理
      println(time + " OPERATION train" + train.id + " が 駅" + currentInfo.stationId +" を通過");
    }

    int i = 0;
    while (finishFlag[i]) {
      i++;  // finishFlagが立っている列車の個数を数えている
      if (i == finishFlag.length) {  // すべての列車の運転が終了したら、初期状態へリセット
        println(time + " OPERATION ダイヤをすべて実施しました。指定時間経過後に初期状態へリセットします");
        resetAll();
        break;
      }
    }
  }
  // 出発処理は列車制御のところで行う
}

// 【列車制御】指定された列車の速度を返す
double getTargetSpeed(Train me) {
  StopPoint stopPoint = getStopPoint(me);  // 停止点取得
  double distance = getDistance(me.currentSection, me.mileage, stopPoint.section, stopPoint.mileage);  // 停止点までの距離を取得
  double targetSpeed = 0.0;
  if (distance > 100) {  // 停止点までの距離に応じて速度を適当に調整
    targetSpeed = MAXSPEED;
  } else if (distance > 0) {
    targetSpeed = distance/100 * MAXSPEED;
  }

  if (finishFlag[me.id] == true) {  // ダイヤを終了した列車については止まってもらう
    targetSpeed = 0;
  }

  // 出発処理
  if (me.targetSpeed == 0 && targetSpeed > 0) {  // targetSpeedがゼロから>0に変化したとき
    if (timetable.getByTrainId(me.id).isDeparture()) {  // 未出発であれば
      timetable.getByTrainId(me.id).used = true;  // 駅を出発済に変更
      println(time + " OPERATION train" + me.id + " が出発");
    }
  }
  state.trainList.get(me.id).targetSpeed = targetSpeed;
    
  return targetSpeed;
}

// 線路上のある点からある点までの距離を返す
double getDistance(Section s1, double mileage1, Section s2, double mileage2) {
  double distance = 0;
  Section testSection = s1;
  
  while (testSection.id != s2.id) {
    distance += testSection.length;
    testSection = testSection.targetJunction.getPointedSection();
  }
  return distance + mileage2 - mileage1;
}

// 【停止点算出】指定された列車の停止点を返す
StopPoint getStopPoint(Train me) {
  Section testSection = me.currentSection;
  do {
    // 現在のセクションに駅があり、そこで停車の場合
    if (isStopping(testSection, me.id)) {
      Info info = timetable.getByStationTrainId(Station.getBySection(testSection).id, me.id);  // その駅の最も近い未実施時刻情報を取得
      // 直近の未実施時刻が、現在セクションにある駅の時刻と同一＝この駅で止まる筈の場合
      if (timetable.getByTrainId(me.id).time == info.time) {
        if (info.isDeparture() && isSignalGo(testSection) && info.time < time/1000) {  // 到着済で、分岐器開通し前方在線なし、出発時刻を過ぎている
          testSection = testSection.targetJunction.getPointedSection();  // 次のsectionへ進む
        } else {  // 出発できない場合は止める
          return new StopPoint(testSection, testSection.stationPosition);
        }
      } else {
        testSection = testSection.targetJunction.getPointedSection();
      }
    // 現在のsectionに駅がないか、あっても通過の場合
    } else {
      if (isSignalGo(testSection)) {  // 分岐器開通し前方在線なし
        testSection = testSection.targetJunction.getPointedSection();  // 次のsectionへ進む
      } else {
        return new StopPoint(testSection, testSection.length - STOPMERGIN);
      }
    }

  } while (testSection.targetJunction.id != me.currentSection.sourceJunction.id);
  // 一周した場合は自列車がいるsectionの手前で停止
  return new StopPoint(testSection, testSection.length - STOPMERGIN);
 
}

// 分岐器が開通し、かつ前方sectionに列車がいない場合trueを返す（＝信号機が赤以外を現示する条件）
Boolean isSignalGo (Section s) {
  if (s.targetJunction.getInSection().id == s.id) {  // 分岐器が開通している
    Train train = detectTrain(s.targetJunction.getPointedSection());  // 前方セクションにいる列車を取得
    if (train == null) {  // 前方セクションに在線なし
      return true;
    }
  }
  return false;
}

// sectionに駅があり、かつtrainが停車する場合trueを返す
Boolean isStopping(Section section, int trainId) {
  if (section.hasStation) {
    Info info = timetable.getByStationTrainId(Station.getBySection(section).id, trainId);  // その駅の最も近い未実施時刻情報を取得
    if (info == null || info.isPassage()) {
      return false;
    }
    return true;
  }
  return false;
}

// 【ポイント制御】時刻表に応じてJunctuionを制御する
Boolean junctionControl(Junction junction) {
  Section inSection = junction.getInSection();
  Section outSection = junction.getPointedSection();
  
  // 列車が分岐器上にいないときに操作を行う（轍鎖鎖錠）
  Train trainOnJunction = detectTrain(outSection);
  if (trainOnJunction == null || trainOnJunction.mileage > TRAINLENGTH) {
    
    // in1->out2 という分岐器の場合、到着する列車の番線に合わせる
    if (junction.inSectionList.size() == 1 && junction.outSectionList.size() > 1) {
      Train inTrain = detectTrain(junction.getInSection());  // 分岐器へ進入する列車を取得
      if (inTrain != null) {  // 列車が近づいて来ているとき
        Info info = timetable.getByTrainId(inTrain.id);  // 近づいてくる列車の時刻情報を取得
        Section arrTrack = Station.getById(info.stationId).trackList.get(info.trackId);  // 近づいてくる列車の着発番線を取得
        if (arrTrack.id != junction.getPointedSection().id) {  // 到着番線と、現在開通している番線が違えば、合わせる
          println(time + " OPERATION Junction" + junction.id+": Toggled");
          return true;
        } else {
          return false;
        }
      } else {
        return false;
      }

    // in2->out1 という分岐器の場合、
    } else if (junction.inSectionList.size() > 1 && junction.outSectionList.size() == 1) {
      Train inTrain = detectTrain(junction.getInSection());  // 分岐器開通方向の列車を取得
      if (inTrain != null) {  // 現在開通している進路に列車がいる場合、この列車がいなくなるまで分岐器が動かないよう鎖錠
        return false;
      } else {  // 鎖錠しない場合、最も早く出発or通過する列車の番線に合わせる
        Station station = getBelongStation(junction);  // junctionが属する駅を取得
        Info info = timetable.getDepartureByTrackId(station.id, station.getTrackIdBySection(inSection));  // とりあえず現在開通している番線の出発時刻情報を取得
        for (Section section : junction.inSectionList) {
          Info tmpInfo = timetable.getDepartureByTrackId(station.id, station.getTrackIdBySection(section));  // 各inSectionの出発時刻情報を取得
          if (info != null && tmpInfo != null && tmpInfo.time < info.time) {  // tmpInfo.timeのほうが早ければinfoを更新
            info = tmpInfo;
          } else if (info == null && tmpInfo != null) {
            info = tmpInfo;
          }
        }
        if (info != null) {  // <-このinfoは、最も早く出発or通過する列車の時刻情報
          if (junction.getInSection().id != station.trackList.get(info.trackId).id) {  // 出発番線と、現在開通している番線が異なれば、合わせる
            println(time + " OPERATION Junction" + junction.id+": Toggled");
            return true;
          } else {
            return false;
          }
        } else {
          return false;
        }
      }
    } else {
      return false;
    }
  } else {
    return false;
  }
  
}

// センサから入力があったとき、列車位置を補正する。id=センサID
void positionAdjust(int id) {
  Sensor s = Sensor.getById(id);  // センサ取得
  Train t = detectTrain(s.belongSection);  // センサがおかれているsectionに在線する列車を取得
  if (t != null) {
    println(time + " OPERATION センサ"+id+"(section="+s.belongSection.id+", position="+s.position+") を 列車"+t.id+" が通過. 列車位置補正:"+t.mileage+"->"+s.position);
    MoveResult move = state.trainList.get(t.id).move(s.position - t.mileage);  // ずれの分だけ列車位置を補正
  } else {
    println(time + " OPERATION センサ"+id+"(section="+s.belongSection.id+", position="+s.position+") から入力がありましたが、当該セクションに在線なし. 位置補正失敗.");
  }
}

// あるsectionにいる列車を返す。列車がいなければnullを返す
Train detectTrain(Section section) {
  for (Train train : state.trainList) {  // 各列車がどのセクションにいるか調べ、引数と一致すれば返す
    if (train.currentSection.id == section.id) {
      return train;
    }
  }
  return null;
}

// Junctionが属する駅を返す
Station getBelongStation(Junction junction) {
  for (Station station : state.stationList) {
    for (int i = 1; i <= station.trackList.size(); i++) {
      if (station.trackList.get(i).sourceJunction.id == junction.id || station.trackList.get(i).targetJunction.id == junction.id) {
        return station;
      }
    }
  }
  return null;
}
