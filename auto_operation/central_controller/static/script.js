import { RemoteControl } from "./remote.js";

const raspi = new RemoteControl();  // ラズパイとのWebRTC通信
var socket = io();  // central_controllerとのwebsockt通信

var speed = 0;
const TITLE_NG = "運転するには、列車番号を入力してください";
const TITLE_OK = "つまみをドラッグすると、プラレールの速度を操作できます";
if (sessionStorage.getItem("pw")) {
  pw_input.value = sessionStorage.getItem("pw");
}

// 【スピードをサーバに送信】0.4secおきに送信する
var timer;
var isTimerOn = false;
mascon.addEventListener('input', function () {
  if (isTimerOn == false) {
    timer = setTimeout(function () {
      speed = parseInt(mascon.value);
      raspi.send(new Uint8Array([speed]));
      console.log(speed);
      isTimerOn = false;
    }, 400);  // ハンドルを動かした0.4sec後に送信
    isTimerOn = true;
  }
});

//【PW照合関係】
pw_send.onclick = function () {
  mascon.style.pointerEvents = 'all';  // ハンドルの操作を許可
  mascon.title = TITLE_OK;
  message.innerText = '列車番号を確認しました！　--時--分 まで自由に運転できます。映像が映ったら運転をはじめてください。';

  var movie = document.getElementById('movie');
  raspi.connect(movie);  // ルームに接続
  stopInstruction();
}

// データが送られてきたとき
raspi.subscribe((data) => {
  const text = new TextDecoder().decode(data);
  console.log(text);
  if (text === 'o') {
    socket.emit('hall', {trainId: 1});
  }
});

//【サイズ調整】
window.onload = controller_resize;  // ロード時にレイアウトを調整
window.onresize = controller_resize; // ウィンドウサイズ変更時にレイアウトを調整
function controller_resize() {
  // div controller のサイズ調整
  var content_width = document.getElementById('content').clientWidth;
  var content_height = document.getElementById('content').clientHeight;
  var controller = document.getElementById('controller')
  if (content_width / content_height > 64 / 27) {  // controllerより横長の表示領域
    controller.style.height = '100%';
    controller.style.width = content_height * 64 / 27 + 'px';
  } else {  // controllerより縦長の表示領域
    controller.style.width = '100%';
    controller.style.height = content_width * 27 / 64 + 'px';
  }
  // マスコンハンドルのサイズ調整
  var area_width = document.getElementById('mascon_area').clientWidth;
  var area_height = document.getElementById('mascon_area').clientHeight;
  mascon.style.width = area_height * 0.667 + 'px';  // 長さ
  mascon.style.marginTop = area_height * 0.5 - 5 + 'px';  // 縦位置を調整
  mascon.style.marginLeft = - (mascon.clientWidth - area_width) / 2 + 'px';  // 横位置ははみ出している分左へ
}

// 説明動画の停止・非表示
function stopInstruction() {
  var instruction = document.getElementById('instruction');
  if (instruction) {
    if (instruction.contentWindow.postMessage) {
      instruction.contentWindow.postMessage(JSON.stringify({
        event: 'command',
        func: 'stopVideo'
      }), '*');
    }
    instruction.remove();
  }
}


// websocket経由で信号を受け取って、信号の表示を切り替える。
// サーバからデータを受信
socket.on('signal_taiken', function (data) {
  if (data['signal'] === 'R') {
    // 赤を表示
    document.getElementById("signal_img").src = "static/img/R.svg";
  } else if (data['signal'] === 'G') {
    // 緑を表示
    document.getElementById("signal_img").src = "static/img/G.svg";
  } else {
    // エラー処理
    console.log(`不正なソケット通信: ${data['signal']}を受信しました`);
  }
  document.getElementById("distance_value").innerText = data['distance'] + " cm";
})

