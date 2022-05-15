#!/usr/bin/env python3

from __future__ import annotations
import subprocess
import re
import os.path
import datetime
import RPi.GPIO as GPIO
import serial
import asyncio
import websockets

MOTOR_PIN = 19
SENSOR_PIN = 10

GPIO.setmode(GPIO.BCM)
GPIO.setup(MOTOR_PIN, GPIO.OUT)
GPIO.setup(SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

motor = GPIO.PWM(MOTOR_PIN, 50)
sensor_value = GPIO.LOW
prev_sensor_value = GPIO.HIGH

MOMO_BIN = os.path.expanduser('~/momo-2020.8.1_raspberry-pi-os_armv6/momo')

process_socat = None
process_momo = None
port = None

# WebSocketで非同期に送受信したデータを溜めているキュー
# 中身はbytes
send_queue: asyncio.Queue[bytes] = asyncio.Queue()
recv_queue: asyncio.Queue[bytes] = asyncio.Queue()

def setup():
    global process_socat, process_momo, port, handle_speed, controlled_speed
    print('starting...')
    process_socat = subprocess.Popen(['socat', '-d', '-d', 'pty,raw,echo=0', 'pty,raw,echo=0'], stderr=subprocess.PIPE)
    port1_name = re.search(r'N PTY is (\S+)', process_socat.stderr.readline().decode()).group(1)
    port2_name = re.search(r'N PTY is (\S+)', process_socat.stderr.readline().decode()).group(1)
    process_socat.stderr.readline()
    print('using ports', port1_name, 'and', port2_name)
    process_momo = subprocess.Popen([
        MOMO_BIN,
        '--no-audio-device',
        '--use-native',
        '--force-i420',
        '--serial', f'{port1_name},9600',
        'test',
    ])
    port = serial.Serial(port2_name, 9600)
    motor.start(0)
    handle_speed = 0
    controlled_speed = 0
    # GPIO.add_event_detect(SENSOR_PIN, GPIO.RISING, callback=on_sensor, bouncetime=10)
    print('started')
    print('motor:', MOTOR_PIN)
    print('sensor:', SENSOR_PIN)
    print('running at http://raspberrypi.local:8080/')
    print('Ctrl+C to quit')

def on_sensor(channel):
    data = b'o\n'
    port.write(data)
    port.flush()
    # send_queue.put_nowait(data)
    print(datetime.datetime.now(), 'send sensor', data)

# WebSocketサーバーを立ててデータを送受信するための定型処理
# 参考: https://websockets.readthedocs.io/en/stable/howto/patterns.html
async def websocket_serve():
    # WebSocketで受信したデータをrecv_queueに入れる
    async def consumer_handler(websocket):
        async for message in websocket:
            await recv_queue.put(message)

    # send_queueにあるデータをWebSocketで送信する
    async def producer_handler(websocket):
        while True:
            message = await send_queue.get()
            await websocket.send(message)

    # 受信と送信のどちらかが落ちたときにもう片方も落とす
    async def handler(websocket):
        consumer_task = asyncio.create_task(consumer_handler(websocket))
        producer_task = asyncio.create_task(producer_handler(websocket))
        done, pending = await asyncio.wait(
            [consumer_task, producer_task],
            return_when=asyncio.FIRST_COMPLETED,
        )
        for task in pending:
            task.cancel()

    # WebSocketサーバーを開始する
    async with websockets.serve(handler, "raspberrypi.local", 8765):
        await asyncio.Future()

def loop():
    speed = None
    global handle_speed, controlled_speed, prev_sensor_value, sensor_value

    if port.in_waiting > 0:
        while port.in_waiting > 0:
            data = port.read()
        handle_speed = data[0]
        print(f"{datetime.datetime.now()} receive user speed. user_speed={handle_speed}, operator_speed={controlled_speed}")

    if not recv_queue.empty():
        while not recv_queue.empty():
            data = recv_queue.get_nowait()
        controlled_speed = int(data)
        print(f"{datetime.datetime.now()} receive operator speed. user_speed={handle_speed}, operator_speed={controlled_speed}")

    if controlled_speed is None:
        speed = handle_speed
    else:
        speed = min(handle_speed, controlled_speed)
    # print(f"handle_speed={handle_speed}, controlled_speed={controlled_speed}")

    dc = speed * 100 / 255
    motor.ChangeDutyCycle(dc)
    # print(datetime.datetime.now(), 'calculated speed      ', speed)

    # ホール検出ごとにPCに信号を送る
    prev_sensor_value = sensor_value
    sensor_value = GPIO.input(SENSOR_PIN)
    if prev_sensor_value == GPIO.LOW and sensor_value == GPIO.HIGH:
        on_sensor(None)

async def async_loop():
    while True:
        loop()
        await asyncio.sleep(0.01)

def main():
    try:
        setup()
        event_loop = asyncio.get_event_loop()
        gather = asyncio.gather(
            async_loop(),
            websocket_serve(),
        )
        event_loop.run_until_complete(gather)
    except KeyboardInterrupt:
        print('interrupted')
    except Exception as e:
        print(e)
    finally:
        motor.stop()
        GPIO.cleanup()
        if port:
            port.close()
        if process_momo:
            process_momo.terminate()
        if process_socat:
            process_socat.terminate()

if __name__ == '__main__':
    main()
