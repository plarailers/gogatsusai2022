#!/usr/bin/env python3

from __future__ import annotations
import datetime
import RPi.GPIO as GPIO
import asyncio

MOTOR_PIN = 19
SENSOR_PIN = 10

GPIO.setmode(GPIO.BCM)
GPIO.setup(MOTOR_PIN, GPIO.OUT)
GPIO.setup(SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

motor = GPIO.PWM(MOTOR_PIN, 50)
sensor_value = GPIO.LOW
prev_sensor_value = GPIO.HIGH

speed = None

def setup():
    global speed
    speed = int(input("input speed: "))
    motor.start(0)
    print('started')

def on_sensor(channel):
    data = b'o\n'
    print(datetime.datetime.now(), 'sensor', data)

def loop():
    global prev_sensor_value, sensor_value

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
    import time
    try:
        setup()
        # event_loop = asyncio.get_event_loop()
        # gather = asyncio.gather(
        #     async_loop(),
        # )
        # event_loop.run_until_complete(gather)
        while True:
            loop()
            time.sleep(0.01)
    except KeyboardInterrupt:
        print('interrupted')
    except Exception as e:
        print(e)
    finally:
        motor.stop()
        GPIO.cleanup()

if __name__ == '__main__':
    main()
