class Node {
    float x;
    float y;

    Node(float x, float y) {
        this.x = x;
        this.y = y;
    }

    void set(float x, float y) {
        this.x = x;
        this.y = y;
    }
}

class Display {
    Node node0 = new Node(100, 300);  // 本線
    Node node1 = new Node(300, 300);
    Node node2 = new Node(500, 300); 
    Node node3 = new Node(700, 300);
    Node node4 = new Node(900, 300);
    Node node5 = new Node(1100, 300);
    Node node6 = new Node(1300, 300);
    Node node7 = new Node(920, 200);  // 柏駅副本線
    Node node8 = new Node(1080, 200);

    void setup() {
        PFont font = createFont("MS Gothic", 36);
        textFont(font);
    }
    void draw(State state){
        background(19,60,36);  // 背景色
        stroke(240,240,240);  // 線の色
        strokeWeight(5);  // 線の太さ
        line(node0.x, node0.y, node1.x, node1.y);  // 本線
        line(node1.x, node1.y, node2.x, node2.y);
        line(node2.x, node2.y, node3.x, node3.y);
        line(node3.x, node3.y, node4.x, node4.y);
        line(node4.x, node4.y, node5.x, node6.y);
        line(node5.x, node5.y, node6.x, node6.y);
        line(node7.x, node7.y, node8.x, node8.y);  // 副本線
        line(node4.x, node4.y, node7.x, node7.y);  // ナナメの線
        line(node5.x, node5.y, node8.x, node8.y);
        stroke(19,60,36);
        line(node1.x   , node0.y-20, node1.x   , node0.y+20);  // 区切り線
        line(node2.x   , node0.y-20, node2.x   , node0.y+20);
        line(node3.x   , node0.y-20, node3.x   , node0.y+20);
        line(node4.x-10, node0.y-20, node4.x-10, node0.y+20);
        line(node5.x+10, node0.y-20, node5.x+10, node0.y+20);
        line(node7.x+10, node7.y-20, node7.x+10, node0.y+20);  
        line(node8.x-10, node7.y-20, node8.x-10, node0.y+20);
        // センサの描画
        // fill(240);
        // strokeWeight(0);
        // rect(821-6, 300-6, 12, 12);
        // rect(1219-6, 300-6, 12, 12);
        // 文字類の描画
        textSize(20);
        textAlign(CENTER);
        fill(240);
        text("駒場 駅 (id=0)",200,100);
        text("本郷 駅 (id=1)",600,100);
        text("柏 駅 (id=2)",1000,100);
        textSize(12);
        text("Section0",200,290);
        text("Section1",400,290);
        text("Section2",600,290);
        text("Section3",800,290);
        text("Section4 (1番線)",1000,290);
        text("Section5 (2番線)",1000,190);
        text("Section6",1200,290);
        
        // 以下で電車の座標を決定
        for (Train state_train : state.trainList) {
            int section_id = state_train.currentSection.id;
            int len = state_train.currentSection.length;
            float position_x = 100;
            float position_y = 200;
            switch (section_id) {  // x座標決定
                case 0:
                    position_x = 100 + 200 * state_train.getPosition();  break;
                case 1:
                    position_x = 300 + 200 * state_train.getPosition();  break;
                case 2:
                    position_x = 500 + 200 * state_train.getPosition();  break;
                case 3:
                    position_x = 700 + 190 * state_train.getPosition();  break;
                case 4:
                case 5:
                    position_x = 930 + 140 * state_train.getPosition();  break;
                case 6:
                    position_x = 1110 + 190 * state_train.getPosition();  break;
            }
            switch (section_id) {  // y座標決定
                case 0:
                case 1:
                case 2:
                case 3:
                case 4:
                case 6:
                    position_y = 300;  break;
                case 5:
                    position_y = 200;  break;
            }
            // 電車の描画
            fill(255,0,0);  // 塗りつぶし色
            strokeWeight(0);
            stroke(19,60,36);
            triangle(position_x-15, position_y-15, position_x-15, position_y+15, position_x+15, position_y);
            fill(255);
            textSize(14);
            textAlign(LEFT);
            text(state_train.id ,position_x-10, position_y+7);  // trainId
            Info info = timetable.getByTrainId(state_train.id);
            String type;
            textSize(10);
            if (info != null) { 
                if (info.isArrival()) {
                    type = "着";
                } else if (info.isDeparture()) {
                    type = "発";
                } else {
                    type = "通";
                }
                text("次時刻:\n" + Station.getById(info.stationId).name + "駅 " +info.trackId+ "番線 " +info.time+type, position_x-10, position_y+20);
            }
        }

        // 時刻の描画
        fill(240);
        textSize(20);
        text("time : "+time/1000, 1200, 400);


        // 信号描画
        Signal sig0Arr = Signal.R;  // 駒場(section0)場内
        if (detectTrain(state.sectionList.get(0)) == null) {
            sig0Arr = Signal.G;
        }
        drawSignal(100,330,2,sig0Arr);

        Signal sig0Dep = Signal.R;  // 駒場(Section0)出発
        if (detectTrain(state.sectionList.get(1)) == null) {
            sig0Dep = Signal.G;
        }
        drawSignal(300,330,2,sig0Dep);

        Signal sig2Arr = Signal.R;  // 本郷(section2)場内
        if (detectTrain(state.sectionList.get(2)) == null) {
            sig2Arr = Signal.G;
        }
        drawSignal(500,330,2,sig2Arr);

        Signal sig2Dep = Signal.R;  // 本郷(Section2)出発
        if (detectTrain(state.sectionList.get(3)) == null) {
            sig2Dep = Signal.G;
        }
        drawSignal(700,330,2,sig2Dep);

        Signal sig4Arr = Signal.R;  // 柏section4場内
        if (detectTrain(state.sectionList.get(4)) == null && state.junctionList.get(3).getPointedSection().id == 4) {
            sig4Arr = Signal.G;
        }
        drawSignal(900,330,2,sig4Arr);

        Signal sig5Arr = Signal.R;  // 柏section5場内
        if (detectTrain(state.sectionList.get(5)) == null && state.junctionList.get(3).getPointedSection().id == 5) {
            sig5Arr = Signal.G;
        }
        drawSignal(900,170,2,sig5Arr);

        Signal sig4Dep = Signal.R;  // 柏Section4出発
        if (detectTrain(state.sectionList.get(6)) == null && state.junctionList.get(4).getInSection().id == 4) {
            sig4Dep = Signal.G;
        }
        drawSignal(1100,330,2,sig4Dep);

        Signal sig5Dep = Signal.R;  // 柏section5出発
        if (detectTrain(state.sectionList.get(6)) == null && state.junctionList.get(4).getInSection().id == 5) {
            sig5Dep = Signal.G;
        }
        drawSignal(1100,170,2,sig5Dep);

        
    }

    void drawSignal(float x, float y, int sigNum, Signal sig) {
        if (sigNum == 2) {  // 2灯式
            fill(19,60,36);
            stroke(240);
            strokeWeight(1);
            line(x, y, x+20, y);
            line(x, y-8, x, y+8);
            circle(x+22, y, 20);
            circle(x+38, y, 20);
            stroke(19,60,36);
            strokeWeight(2);
            rect(x+22, y-10, 16, 20);
            stroke(240);
            strokeWeight(1);
            line(x+22, y-10, x+38, y-10);
            line(x+22, y+10, x+38, y+10);
            stroke(19,60,36);
            strokeWeight(0);
            if (sig == Signal.R) {
                fill(255,0,0);
                circle(x+24, y, 10);
                fill(10);
                circle(x+36, y, 10);
            } else {
                fill(0,180,70);
                circle(x+36, y, 10);
                fill(10);
                circle(x+24, y, 10);
            }
        }

    }
}

enum Signal {
    R,
    Y,
    G
}
