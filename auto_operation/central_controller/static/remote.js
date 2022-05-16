/**
 * Raspberry Pi との映像通信を管理する。
 * 主な使い方は以下の通り。
 *
 * ```
 * const raspi = new RemoteControl();
 *
 * // ラズパイに接続し、映像を <video /> 要素に映す。
 * raspi.connect(videoElement);
 *
 * // ラズパイにデータ (Uint8Array) を送る。
 * raspi.send(data);
 *
 * // ラズパイからデータ (Uint8Array) が来たときの処理。
 * raspi.subscribe((data) => {
 *   //
 * });
 * ```
 */

/**
 * @type { import("@open-ayame/ayame-web-sdk") }
 */
const Ayame = window.Ayame;

/**
 * @typedef { import("@open-ayame/ayame-web-sdk/src/connection").default } AyameConnection
 */

export class RemoteControl {
  constructor() {
    /**
     * @private
     * @type { AyameConnection | null }
     */
    this.conn = null;

    /**
     * @private
     * @type { RTCDataChannel | null }
     */
    this.dataChannel = null;

    /**
     * @private
     * @type { MediaStream | null }
     */
    this.stream = null;

    /**
     * @private
     * @type { HTMLVideoElement | null }
     */
    this.videoElement = null;

    /**
     * @private
     * @type { ((data: Uint8Array) => void) | null }
     */
    this.subscription = null;
  }

  /**
   * Momo との接続を開始する。
   * @param { HTMLVideoElement } videoElement 映像を写したい <video /> 要素。
   */
  async connect(videoElement) {
    this.videoElement = videoElement;

    const conn = Ayame.connection("ws://raspberrypi.local:8080/ws", "", {
      ...Ayame.defaultOptions,
      audio: { enabled: false },
      video: { direction: "recvonly", enabled: true, codec: "H264" },
    });

    this.conn = conn;

    conn.connect(null);

    conn.on("open", async () => {
      console.log("ayame", "open");

      const dataChannel = await conn.createDataChannel("serial");

      console.log("ayame", "datachannel");

      if (!dataChannel) {
        throw new Error("Failed to create dataChannel");
      }

      this.dataChannel = dataChannel;

      dataChannel.addEventListener("message", (event) => {
        if (typeof this.subscription === "function") {
          this.subscription(event.data);
        }
      });
    });

    conn.on("addstream", (event) => {
      console.log("ayame", "addstream");

      this.stream = event.stream;

      videoElement.srcObject = event.stream;
      videoElement.play();
    });

    conn.on("disconnect", (event) => {
      console.log("ayame", "disconnect");
    });
  }

  /**
   * Momo との接続を終了する。多分使わない。
   */
  async disconnect() {
    const videoElement = this.videoElement;
    if (videoElement) {
      videoElement.srcObject = null;
      videoElement.pause();
    }

    const conn = this.conn;
    if (conn) {
      await conn.disconnect();
    }
  }

  /**
   * Momo にデータを送信する。
   * @param { Uint8Array } data 送信したいバイナリデータ。
   */
  send(data) {
    const dataChannel = this.dataChannel;
    if (dataChannel && dataChannel.readyState === "open") {
      dataChannel.send(data);
    }
  }

  /**
   * Momo からデータを受信したときの処理を決める。
   * @param { (data: Uint8Array) => void } callback データを受信したときの処理
   */
  subscribe(callback) {
    this.subscription = callback;
  }
}
