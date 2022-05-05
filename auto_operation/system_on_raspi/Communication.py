import platform
import serial
import queue
import time
from numpy import pi
from Components import Junction
from Components import Train

# ESP32 や Arduino との通信をまとめる。
# シミュレーションモードを使うと接続が無くてもある程度動作確認できる。


class Communication:
    class TrainSignal:
        def __init__(self, trainId: int):
            self.trainId = trainId

    def __init__(self, pidParamMap: dict[int, Train.PIDParam]):
        self.simulationMode = False
        self.simulationSpeedMap: dict[int, int] = {}
        self.pidParamMap = pidParamMap
        self.prevUpdate = 0.0
        self.arduino = None
        self.esp32Map: dict[int, serial.Serial] = {}
        self.deltaMap: dict[int, float] = {}
        self.sensorSignalBuffer = queue.Queue()

    def setup(self, simulationMode):
        self.simulationMode = simulationMode
        osName = platform.system()
        isWindows = osName.startswith("Windows")
        if self.simulationMode:
            if isWindows:
                self.simulationSpeedMap[0] = 0.0
                self.simulationSpeedMap[1] = 0.0
                self.deltaMap[0] = 0.0
                self.deltaMap[1] = 0.0
                self.arduino = serial.Serial("COM8", 9600)
            else:
                self.simulationSpeedMap[0] = 0.0
                self.simulationSpeedMap[1] = 0.0
                self.deltaMap[0] = 0.0
                self.deltaMap[1] = 0.0
                # self.arduino = serial.Serial("/dev/ttyS0", 9600)
        else:
            if isWindows:
                self.esp32Map[0] = serial.Serial("COM5", 115200)
                self.esp32Map[1] = serial.Serial("COM6", 115200)
                self.arduino = serial.Serial("COM8", 9600)
            else:
                self.esp32Map[0] = serial.Serial("/dev/cu.ESP32-ESP32SPP", 115200)
                self.esp32Map[1] = serial.Serial("/dev/cu.ESP32-ESP32Dr.", 115200)
                self.arduino = serial.Serial("/dev/ttyS0", 9600)
        self.update()

    def update(self):
        now = time.time()
        dt = now - self.prevUpdate
        self.prevUpdate = now

        if (self.simulationMode):
            for trainId in self.deltaMap.keys():
                self.deltaMap[trainId] += self.simulationSpeedMap[trainId] * dt

            if self.arduino != None:
                while self.arduino.in_waiting > 0:
                    self.sensorSignalBuffer.put(self.arduino.read())

        else:
            for trainId in self.esp32Map.keys():
                esp32 = self.esp32Map[trainId]
                if esp32 != None:
                    while esp32.in_waiting > 0:
                        # ホールセンサ信号が来たら、車輪0.5回転分deltaを進める
                        self.deltaMap[trainId] += 2 * pi * self.pidParamMap[trainId].r / 2
                        # 同時刻に複数の信号が来る不具合のため、1回のループですべて消費する
                        while esp32.in_waiting > 0:
                            esp32.read()

            if self.arduino != None:
                while self.arduino.in_waiting > 0:
                    self.sensorSignalBuffer.put(self.arduino.read())

    def receiveTrainDelta(self, trainId) -> float:
        retval = self.deltaMap[trainId]
        self.deltaMap[trainId] = 0.0
        return retval

    def availableSensorSignal(self) -> int:
        return self.sensorSignalBuffer.qsize()

    def receiveSensorSignal(self) -> int:
        return self.sensorSignalBuffer.get()

    # 指定した車両にspeedを送る. PID制御もここで行う
    def sendSpeed(self, trainId: int, speed: float):
        if self.simulationMode:
            self.simulationSpeedMap[trainId] = speed
        else:
            if self.esp32Map[trainId] != None:
                if speed > 0.1:
                    INPUT_MIN = self.pidParamMap[trainId]
                    KP = self.pidParamMap[trainId]
                    input = int(INPUT_MIN + speed * KP)  # kp制御のみ
                else:
                    input = 0
                self.esp32Map[trainId].write(input.to_bytes(1))

    # 指定したポイントに切替命令を送る
    def sendToggle(self, servoId: int, servoState: Junction.ServoState):
        if self.arduino != None:
            servoStateCode = 0
            if servoState == Junction.ServoState.NoServo:
                return
            elif servoState == Junction.ServoState.Straight:
                servoStateCode = 0
            elif servoState == Junction.ServoState.Curve:
                servoStateCode = 1
            else:
                return
            self.arduino.write(servoId.to_bytes(1, byteorder='little'))
            self.arduino.write(servoStateCode.to_bytes(1, byteorder='little'))
            print(f"[Communication.sendToggle] servoId {servoId} toggle to {servoStateCode}")