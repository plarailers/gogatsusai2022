from Operation import *
from flask import Flask, render_template, Response
from flask_socketio import SocketIO
import threading

# 自動運転システムの初期化
operation = Operation()
operation.state.communication.setup(simulationMode=False)

# Flaskウェブサーバの初期化
app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app)

# 自動運転システムが0.1secおきに実行する作業
def operation_loop():
    while True:
        operation.update()
        train_taiken = operation.state.getTrainById(1)  # ラズパイ体験車(id=1)を取得
        # print(f"[main.operation_loop] t0.section: {operation.state.getTrainById(0).currentSection.id}, t0.mil: {operation.state.getTrainById(0).mileage:.2f}, t0.spd: {operation.state.getTrainById(0).targetSpeed:.2f}, t1.section: {operation.state.getTrainById(1).currentSection.id}, t1.mil: {operation.state.getTrainById(1).mileage:.2f}, t1.spd: {operation.state.getTrainById(1).targetSpeed:.2f}")
        time.sleep(0.01)

# ブラウザにwebsocketで0.1secおきに信号を送る関数
def send_signal_to_browser():
    while True:
        socketio.sleep(0.1)
        train_taiken = operation.state.getTrainById(1)  # ラズパイ体験車(id=1)を取得
        signal = operation.signalSystem.getSignal(train_taiken.currentSection.id, train_taiken.currentSection.targetJunction.getOutSection().id)  # 体験車から見た信号機を取得
        distance = operation.ato.getDistanceUntilStop(train_taiken)  # 停止位置までの距離を取得

        # websocketで送信
        socketio.emit('signal_taiken', {
            'signal': signal.value,
            'distance': int(distance)
        })

@app.route('/')
def index():
    # ブラウザへデータを送信するタスクの開始
    socketio.start_background_task(target=send_signal_to_browser)
    # ブラウザにwebページのデータを返す
    return render_template('index.html')

@socketio.on('hall')  # ホールセンサ信号受信時
def handle_hall(data):
    trainId = data['trainId']
    operation.state.communication.deltaMap[trainId] += 2 * pi * operation.state.communication.pidParamMap[trainId].r / 2
    print(f"[main.py] receive o from train {data['trainId']}")

if __name__ == "__main__":
    thread1 = threading.Thread(target=operation_loop, daemon=True)
    thread1.start()  # 自動運転のオペレーションを開始
    socketio.run(app, host='0.0.0.0', port=50050)  # Flaskソケットを起動
