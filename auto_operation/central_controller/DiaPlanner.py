from State import *

# ダイヤを管理、更新する
# Diaクラスの意味:
#   { trainId: 0,
#     stationId: 1,
#     wait: False,
#     stopTime: 0,
#     arriveSectionId: 2,
#     destSectionId: 4 }
#   -> 列車0は駅1で最低0秒停車=通過. section2に到着しsection4へ出発
#   { trainId: 1,
#     stationId: 1,
#     wait: True,
#     stopTime: 10,
#     arriveSectionId: 3,
#     destSectionId: 4 }
#   -> 列車1は駅1で退避. 最低10秒停車. section3に到着しsection4へ出発


class Dia:
    def __init__(self, trainId: int, stationId: int, wait: bool, stopTime: int, arriveSectionId: int, destSectionId: int):
        self.trainId = trainId
        self.stationId = stationId
        self.wait = wait
        self.stopTime = stopTime
        self.arriveSectionId = arriveSectionId
        self.destSectionId = destSectionId


class DiaPlanner:
    def __init__(self, state: State):
        self.__state = state
        self.__autoUpdate = True  # 自動更新の有効/無効
        self.__diaList: list[Dia] = []  # ダイヤリスト
        for train in self.__state.trainList:  # trainIdとstationIdからダイヤリストを生成
            for station in self.__state.stationList:
                self.__diaList.append(Dia(train.id, station.id, False, 10, 0, 0))

    # ダイヤ自動更新の初期値を記述
    def setup(self) -> None:
        # 今回は、列車0を追い抜き、列車1を退避として初期値をセット
        self.setDia(0, 0, False, 5, 0, 1)
        self.setDia(1, 0, False, 5, 0, 1)
        self.setDia(0, 1, False, 0, 2, 4)
        self.setDia(1, 1, True, 5, 3, 4)

    # ダイヤ自動更新のルールを記述. 毎update時によぶ
    def update(self) -> None:
        if self.__autoUpdate:
            # 今回は、駅1の待避線(section3)に退避列車(wait=True)がいる状況でsection4に列車が出て行ったとき、
            # 追い抜き成功と判断し、train0と1の退避フラグを反転させる
            waitingTrain = self.__state.getTrainInSection(self.__state.getSectionById(3))  # section3の列車を取得
            if waitingTrain != None and self.getDia(waitingTrain.id, 1).wait == True:
                for train in self.__state.trainList:
                    # sectionが変化した瞬間だけ、mileageがprevmileageより小さくなることを利用し、section4に入った瞬間を検知
                    if train.currentSection.id == 4 and train.mileage < train.prevMileage:
                        # 列車0,1のフラグを反転させる
                        if self.getDia(0, 1).wait == True:  # 列車0は直前まで退避していた
                            self.setDia(0, 1, False, 0, 2, 4)  # 列車0を追い抜きに
                            self.setDia(1, 1, True, 10, 3, 4)  # 列車1を退避に
                        else:
                            self.setDia(0, 1, True, 10, 3, 4)
                            self.setDia(1, 1, False, 0, 2, 4)
                        print("[DiaPlanner.update] wait flag switched!")

    # 指定した列車の、指定した駅に対するダイヤを取得
    def getDia(self, trainId: int, stationId: int) -> Dia:
        result = list(filter(lambda x: (x.trainId == trainId and x.stationId == stationId), self.__diaList))
        return result[0]

    # 指定した列車の、指定した駅に対するダイヤを更新
    def setDia(self, trainId: int, staionId: int, wait: bool, stopTime: int, arriveSectionId: int, destSectionId: int) -> None:
        for dia in self.__diaList:
            if dia.trainId == trainId and dia.stationId == staionId:
                dia.wait = wait
                dia.stopTime = stopTime
                dia.arriveSectionId = arriveSectionId
                dia.destSectionId = destSectionId
                break

    # ダイヤ自動更新を有効/無効化
    def setAutoUpdateEnabled(self, enabled: bool) -> None:
        self.__autoUpdate = enabled
