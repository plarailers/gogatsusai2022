class Timetable {
  ArrayList<Info> infoList;
  Timetable() {
    // csv時刻表データ読込
    Table timeTable = loadTable("Table_3station.csv", "header");
    timeTable.sort("time");  // 時刻で辞書順ソート
    infoList = new ArrayList<Info>();
    InfoType type = InfoType.Arrival;
    int time = 0;
    int trainId = 0;
    int stationId = 0;
    int trackId = 0;
    for (int i = 0; i < timeTable.getRowCount(); i++) {  // 各Infoの取得
      switch (timeTable.getString(i, "type")) {
        case "Arrival" :
          type = InfoType.Arrival; break;
        case "Departure" :
          type = InfoType.Departure; break;
        case "Passage" :
          type = InfoType.Passage; break;
      }
      time = timeTable.getInt(i, "time");
      trainId = timeTable.getInt(i, "trainId");
      stationId = timeTable.getInt(i, "stationId");
      trackId = timeTable.getInt(i, "trackId");
      infoList.add(new Info(type, time, trainId, stationId, trackId));
    }
        
  }
  
  // (from, to] の時刻情報を全て得る
  ArrayList<Info> get(int from, int to) {
    ArrayList<Info> result = new ArrayList<Info>();
    for (Info info : infoList) {
      if (from < info.time && info.time <= to) {
        result.add(info);
      }
    }
    return result;
  }

  // trainId の最も近い未実施時刻情報を得る
  Info getByTrainId(int id) {
    for (Info info : infoList) {
      if (info.trainId == id && info.used == false) {
        return info;
      }
    }
    return null;  // すべての時刻を実施済ならnull返す
  }

  // trainId のある駅の最も近い未実施時刻情報を得る
  Info getByStationTrainId(int stationId, int trainId) {
    for (Info info : infoList) {
      if (info.stationId == stationId && info.trainId == trainId && info.used == false) {
        return info;
      }
    }
    return null;
  }

  // ある駅のある番線を最も早く出発or通過する時刻情報を得る
  Info getDepartureByTrackId(int stationId, int trackId) {
    for (Info info : infoList) {
      if (info.stationId == stationId && info.trackId == trackId && info.used == false) {
        if (info.type == InfoType.Departure || info.type == InfoType.Passage) {
          return info;
        }
      }
    }
    return null;
  }

  // すべての時刻情報を「未実施」にリセット
  void reset() {
    for (Info info : infoList) {
      info.used = false;
    }
  }
}

enum InfoType {
  Arrival,    // 到着
  Departure,  // 出発
  Passage     // 通過
}

class Info {
  InfoType type;  // 到着か出発か
  int time;       // 時刻
  int trainId;    // 列車ID
  int stationId;    // 駅ID
  int trackId;     // 着発番線ID
  boolean used;  // 着/発済の時刻であればtrueになる
  Info(InfoType type, int time, int trainId, int stationId, int trackId) {
    this.type = type;
    this.time = time;
    this.trainId = trainId;
    this.stationId = stationId;
    this.trackId = trackId;
    this.used = false;
  }
  
  boolean isArrival() {
    return type == InfoType.Arrival;
  }
  
  boolean isDeparture() {
    return type == InfoType.Departure;
  }

  boolean isPassage() {
    return type == InfoType.Passage;
  }
}
