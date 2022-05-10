from Components import *
from State import *
from DiaPlanner import *
from PointInterlock import *

# ダイヤ情報をもとにポイントの自動切換えを行う
class PointSwitcher:
    def __init__(self, state: State, diaPlanner: DiaPlanner, pointInterLock: PointInterlock):
        self.__state = state
        self.__diaPlanner = diaPlanner
        self.__pointInterlock = pointInterLock
        self.__autoToggle = True

    # ポイント自動切り替えを有効/無効化
    def setAutoToggleEnabled(self, enabled: bool) -> None:
        self.__autoToggle = enabled

    # 状態に応じてポイントを自動で切り替える. 毎update時に呼ぶこと
    def update(self) -> None:
        for junction in self.__state.junctionList:

            # in1->out2 という分岐器の場合、out側を到着列車が入線する番線に合わせる
            if junction.inSectionCurve == None and junction.outSectionCurve != None:
                train = self.__getNearestTrain(junction)  # junctionに一番先に到着する列車を取得
                dia = self.__diaPlanner.getDia(train.id, junction.belongStation.id)  # このjunctionが存在する駅のダイヤ情報を取得
                if dia.arriveSectionId != junction.getOutSection().id:
                    self.__pointInterlock.requestToggle(junction.id)
            # in2->out1 という分岐器の場合、in側を出発列車の存在する番線に合わせる
            elif junction.inSectionCurve != None and junction.outSectionCurve == None:
                train = self.__getNearestTrain(junction)  # junctionを一番先に通る列車を取得
                dia = self.__diaPlanner.getDia(train.id, junction.belongStation.id)  # このjunctionが存在する駅のダイヤ情報を取得
                if dia.arriveSectionId != junction.getInSection().id:
                    self.__pointInterlock.requestToggle(junction.id)

    # 指定したjunctionに一番先に到着する列車を取得する
    def __getNearestTrain(self, junction: Junction, originalJunction: Junction = None) -> Train:

        # まず、指定したjunctionから線路を辿り、junctionに先に到着する可能性のある列車をすべて取得する
        # 駅の出口など、inSectionが複数あるjunctionを指定した場合、trainsは2つ以上の候補がある
        trains: list[Train] = []
        testJunction = junction

        # 何も見つけられずに最初の地点に戻ってきてしまった場合、終了
        if originalJunction != None and junction.id == originalJunction.id:
            return trains

        if originalJunction == None:
            originalJunction = junction

        while True:
            train = self.__state.getTrainInSection(testJunction.inSectionStraight)
            if train:
                trains.append(train)
            else:
                testJunction = testJunction.inSectionStraight.sourceJunction
                trains.append(self.__getNearestTrain(testJunction, originalJunction))

            # inSectionがひとつだけの分岐であれば、ここで終了
            if testJunction.inSectionCurve == None:
                break
            # inSectionが2つある場合、Curve側も調べる
            else:
                train = self.__state.getTrainInSection(testJunction.inSectionCurve)
                if train:
                    trains.append(train)
                else:
                    testJunction = testJunction.inSectionCurve.sourceJunction
                    trains.append(self.__getNearestTrain(testJunction, originalJunction))
                break

        trains = list(set(trains))  # 重複を削除

        # 候補となる列車が1つの場合はそれを返す
        if len(trains) == 1:
            return trains[0]
        # 複数の候補がある場合、ダイヤと照らしあわせることで最も先にポイントを通過する列車を絞り込む
        else:
            # junction直前の駅を取得
            station = self.__getNearestStation(junction)
            # 駅で退避するつもりのないtrainをfilter
            trainsWantToGo = list(filter(lambda t: self.__diaPlanner.getDia(t.id, station.id).wait == False, trains))
            # 全列車が退避したい場合、どれを先に出すか決めようがないので、とりあえず0番を返す
            if len(trainsWantToGo) == 0:
                return trains[0]
            # 退避するつもりのない(追い抜きたい)列車が1つのとき、それを先に行かせる
            elif len(trainsWantToGo) == 1:
                return trainsWantToGo[0]
            # 退避するつもりのない列車が2つ以上のとき、最もjunctionに近いものを返す
            else:
                trainsWantToGo.sort(key=lambda t: self.__state.getDistance(t.currentSection, t.mileage, junction.getOutSection(), 0))
                return trainsWantToGo[0]

    # 指定したjunctionの直前にある駅を取得
    def __getNearestStation(self, junction: Junction) -> Station:
        searchSection = junction.inSectionStraight
        while searchSection.station == None:
            searchSection = searchSection.sourceJunction.inSectionStraight
        return searchSection.station
