import 'dart:io';
import 'package:intl/intl.dart' show DateFormat;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:media_kit/media_kit.dart'; // Provides [Player], [Media], [Playlist] etc.
import 'package:media_kit_video/media_kit_video.dart'; // Provides [VideoController] & [Video] etc.
import 'package:file_picker/file_picker.dart';

import 'package:subtitle_editor/editor/subtitles.dart';
import 'package:subtitle_editor/editor/time.dart';
import 'package:subtitle_editor/editor/action_button.dart';
import 'package:subtitle_editor/editor/import/srt.dart' as srt;
import 'package:subtitle_editor/editor/export/srt.dart' as srt;
import 'package:subtitle_editor/collections/result.dart';

// Размер проигрывателя - 16 на 9
const playerRatio = 9.0 / 16.0;
// Часть экрана (окна), отведённая под плеер
const playerPortion = 0.7;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Обязательная инициализации пакета media kit
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subtitle editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home:
          const MyHomePage(), //Прямо тут можно задать новое имя, передаётся в [MyHomePage()]
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class IncrementIntent extends Intent {
  const IncrementIntent();
}

class IncrementIntent2 extends Intent {
  const IncrementIntent2();
}

class EscIntent extends Intent {
  const EscIntent();
}

class _MyHomePageState extends State<MyHomePage> {
  // Создаём плеер и управление плейером
  late Player player = Player();
  late VideoController controller = VideoController(player);
  late SubtitleTrack subtitle = player.state.track.subtitle;
  final ScrollController _controller2 = ScrollController();

  // Добавляет фокус для перемещения на видео при нажатии esc
  late final FocusNode videoFocusNode;

  var subs = SubtitleTable();
  int _selectedIndex = -1;
  List<Subtitle> savedSubs = [];
  int timeSchange = -1;
  int timeEchange = -1;
  bool selectChange = false;
  bool isDoubleTap = false;

  // импорт видео в программу
  void getFileVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    if (result != null) {
      String videoFilePath = result.files.single.path!;
      player.open(Media(videoFilePath));
      player.setSubtitleTrack(SubtitleTrack.uri("auto.srt"));
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select video file'),
      ));
    }
  }

  // импорт субтитров в таблицу
  void getFileSubtitle() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'srt'],
    );
    if (result != null) {
      String fileSubPath = result.files.single.path as String;
      player.setSubtitleTrack(SubtitleTrack.uri(fileSubPath.toString()));
      subs.export(File("auto.srt"), srt.export);
      savedSubs.clear();
      setState(() {});
      build.call(context);
      setState(() {});
      switch (SubtitleTable.import(File(fileSubPath.toString()), srt.import)) {
        case Ok(value: final v):
          subs = v;
          setState(() {});
        case Err(value: final e):
          print(e);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select subtitle file'),
      ));
    }
  }

  // Функция для вставки видео в плейер
  @override
  void initState() {
    super.initState();

    videoFocusNode = FocusNode();
  }

  @override
  void dispose() {
    player.dispose();
    videoFocusNode.dispose();
    super.dispose();
  }

  void _tellTime() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Video is on ${player.state.position}"),
      duration: Duration(milliseconds: 400),
    ));

    for (var i = 0; i < subs.length - 1; i++) {
      if (subs[i].start.ticks < player.state.position.inMilliseconds &&
          player.state.position.inMilliseconds < subs[i + 1].start.ticks) {
        scrollToIndex(i, 0);
      }
    }
  }

  void scrollToIndex(int index, double step) {
    _controller2.jumpTo(90.0 * (index + 1 + step));
  }

  void completeTimeStart() {
    if (timeSchange != -1) {
      int ind = subs.edit(_selectedIndex, (editor) {
        editor.start = Millis(timeSchange);
        return true;
      });
      scrollToIndex(ind, -4);
      _selectedIndex = ind;
      timeSchange = -1;
      setState(() {});
    }
  }

  void editTimeStart(final value) {
    DateTime tt;
    try {
      tt = DateFormat('HH:mm:ss,S').parse(value);
      int tick = tt.hour * 60 * 60 * 1000;
      tick = tick + tt.minute * 60 * 1000;
      tick = tick + tt.second * 1000;
      tick = tick + tt.millisecond;
      timeSchange = tick;
    } catch (e) {
      print(e);
    }
  }

  void completeTimeEnd() {
    if (timeEchange != -1) {
      int ind = subs.edit(_selectedIndex, (editor) {
        editor.end = Millis(timeEchange);
        return true;
      });
      scrollToIndex(ind, -4);
      _selectedIndex = ind;
      timeEchange = -1;
      setState(() {});
    }
  }

  void editTimeEnd(final value) {
    DateTime tt;
    try {
      tt = DateFormat('HH:mm:ss,S').parse(value);
      int tick = tt.hour * 60 * 60 * 1000;
      tick = tick + tt.minute * 60 * 1000;
      tick = tick + tt.second * 1000;
      tick = tick + tt.millisecond;
      timeEchange = tick;
    } catch (e) {
      print(e);
    }
  }

  void editLine(final value, int index) {
    subs[index];
    subs.edit(index, (editor) {
      editor.text = value;
      return true;
    });
  }

  int editindex = -2;

  void setTime() {
    subs.insert(-1, (editor) {
      editor.text = "";
      editor.start = Millis(player.state.position.inMilliseconds);
      editor.end = Millis(player.state.position.inMilliseconds + 100);
      return true;
    });
    setState(() {});
  }

  void setStartTime() {
    if (editindex == -2) {
      int ind = subs.insert(-1, (editor) {
        editor.text = "";
        editor.start = Millis(player.state.position.inMilliseconds);
        editor.end = Millis(player.state.position.inMilliseconds + 100);
        return true;
      });
      editindex = ind;
    } else {
      subs.edit(editindex, (editor) {
        editor.start = Millis(player.state.position.inMilliseconds);
        return true;
      });
    }
  }

  void setEndTime() {
    if (editindex != -2) {
      subs.edit(editindex, (editor) {
        editor.end = Millis(player.state.position.inMilliseconds);
        return true;
      });
      setState(() {});
    }
    editindex = -2;
  }

  void deleteSub() {
    for (var i = 0; i < subs.length - 1; i++) {
      if (subs[i].start.ticks < player.state.position.inMilliseconds &&
          player.state.position.inMilliseconds < subs[i + 1].start.ticks) {
        savedSubs.add(subs[i]);
        subs.edit(i, (_) => false);
        if (savedSubs.length == 100) {
          savedSubs.removeAt(0);
        }
        setState(() {});
      }
    }
  }

  void exportSubs() async {
    final result = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['txt', 'srt'],
    );
    subs.export(File(result.toString()), srt.export);
  }

  void pressedCtrlZ() {
    if (savedSubs.isEmpty) {
      return;
    }
    var s = savedSubs[savedSubs.length - 1];
    subs.insert(-1, (editor) {
      editor.text = s.text;
      editor.start = s.start;
      editor.end = s.end;
      return true;
    });
    savedSubs.removeAt(savedSubs.length - 1);
    setState(() {});
  }

  void pressedDel() {
    if (_selectedIndex == -1) {
      return;
    }
    savedSubs.add(subs[_selectedIndex]);
    subs.edit(_selectedIndex, (_) => false);
    if (savedSubs.length == 100) {
      savedSubs.removeAt(0);
    }
    setState(() {});
    _selectedIndex == -1;
  }

  void pressedEsc() {
    //videoFocusNode.requestFocus();
    FocusScopeNode currentFocus = FocusScope.of(context);
    currentFocus.unfocus();
    //videoFocusNode.requestFocus();
  }

  void toTimeVideo() {
    Millis time = subs[_selectedIndex].start;
    player.seek(Duration(
        hours: time.format().hour,
        minutes: time.format().minute,
        seconds: time.format().second,
        milliseconds: time.format().millisecond));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        //Верхняя часть с именем
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("Subtitle Editor"),
      ),
      body: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(
                  LogicalKeyboardKey.keyZ, LogicalKeyboardKey.controlLeft):
              const IncrementIntent(),
          LogicalKeySet(
                  LogicalKeyboardKey.delete, LogicalKeyboardKey.shiftRight):
              const IncrementIntent2(),
          LogicalKeySet(LogicalKeyboardKey.escape): const EscIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            IncrementIntent: CallbackAction<IncrementIntent>(
              onInvoke: (IncrementIntent intent) => pressedCtrlZ(),
            ),
            IncrementIntent2: CallbackAction<IncrementIntent2>(
              onInvoke: (IncrementIntent2 intent) => pressedDel(),
            ),
            EscIntent: CallbackAction<EscIntent>(
              onInvoke: (EscIntent intent) => pressedEsc(),
            )
          },
          child: Row(
            //Тело, разделённое по колонкам
            children: [
              Column(
                children: [
                  SizedBox(
                    // Коробка под видео
                    width: width * playerPortion,
                    //width: MediaQuery.of(context).size.width,
                    height: width * playerPortion * playerRatio,
                    // Use [Video] widget to display video output.
                    child: Focus(
                        focusNode: videoFocusNode,
                        child: Video(
                          controller: controller,
                        )),
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.01,
                  ),
                  Row(
                    spacing: width * 0.02, // Помним, 0,7 отведено под плеер

                    // Для кнопок нужно разделить пространство по столбикам
                    children: [
                      // Кнопка со временем
                      ActionButton(
                        tooltip: 'Tells the time',
                        width: width * 0.06,
                        height: width * 0.06,
                        onPressed: _tellTime,
                        icon: Icons.access_time_outlined,
                      ),

                      // Кнопка выбора видеофайла
                      ActionButton(
                        tooltip: 'Choose video file',
                        width: width * 0.06,
                        height: width * 0.06,
                        onPressed: getFileVideo,
                        icon: Icons.video_call_rounded,
                      ),

                      // Кнопка выбора файла субтитров
                      ActionButton(
                        tooltip: 'Choose subtitle file',
                        width: width * 0.06,
                        height: width * 0.06,
                        onPressed: getFileSubtitle,
                        icon: Icons.text_snippet_rounded,
                      ),

                      SizedBox(
                        width: width * 0.01,
                      ),

                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: width * 0.01,
                          children: [
                            ActionButton(
                                tooltip: "Set time",
                                height: width * 0.03,
                                width: width * 0.03,
                                onPressed: setTime,
                                icon: Icons.timer_outlined),
                            ActionButton(
                              tooltip: 'Set start-time',
                              width: width * 0.03,
                              height: width * 0.03,
                              onPressed: setStartTime,
                              icon: Icons.more_time,
                            ),
                            ActionButton(
                              tooltip: 'Set end-time',
                              width: width * 0.03,
                              height: width * 0.03,
                              onPressed: setEndTime,
                              icon: Icons.timer_rounded,
                            ),
                            ActionButton(
                              tooltip: 'Delete sub',
                              width: width * 0.03,
                              height: width * 0.03,
                              onPressed: deleteSub,
                              icon: Icons.auto_delete,
                            ),
                            ActionButton(
                              tooltip: 'Export subtitles',
                              width: width * 0.03,
                              height: width * 0.03,
                              onPressed: exportSubs,
                              icon: Icons.save_alt,
                            ),
                          ]),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: ListView.builder(
                    // Построитель списка для субтитров
                    controller: _controller2,
                    itemCount: subs.length, // количество субтитров
                    itemBuilder: (context, i) => Row(
                          children: [
                            Flexible(
                                child: ListTile(
                              onTap: () {
                                if (_selectedIndex != i) {
                                  isDoubleTap = false;
                                }
                                if (isDoubleTap) {
                                  toTimeVideo();
                                  isDoubleTap = false;
                                } else {
                                  isDoubleTap = true;
                                }
                                setState(() {
                                  _selectedIndex = i;
                                });
                              },
                              selected: i == _selectedIndex,
                              title: Row(children: [
                                SizedBox(
                                  width: width * 0.08,
                                  child: TextField(
                                    onTap: () {
                                      _selectedIndex = i;
                                    },
                                    controller: TextEditingController()
                                      ..text = DateFormat('HH:mm:ss,S').format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                              subs[i].start.ticks,
                                              isUtc: true)),
                                    onChanged: (value) =>
                                        {editTimeStart(value)},
                                    onEditingComplete: () => {
                                      completeTimeStart(),
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 0),
                                    ),
                                  ),
                                ),
                                Text(" - "),
                                SizedBox(
                                  width: width * 0.08,
                                  child: TextField(
                                    onTap: () {
                                      _selectedIndex = i;
                                    },
                                    controller: TextEditingController()
                                      ..text = DateFormat('HH:mm:ss,S').format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                              subs[i].end.ticks,
                                              isUtc: true)),
                                    onChanged: (value) => {editTimeEnd(value)},
                                    onEditingComplete: () => {
                                      completeTimeEnd(),
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 0),
                                    ),
                                  ),
                                ),
                              ]),
                              subtitle: TextFormField(
                                onTap: () {
                                  _selectedIndex = i;
                                },
                                controller: TextEditingController()
                                  ..text = subs[i].text,
                                minLines: 1,
                                maxLines: 3,
                                onChanged: (value) => {editLine(value, i)},
                                onEditingComplete: () => {
                                  setState(() {
                                    _selectedIndex = i;
                                  }),
                                },
                              ),
                              onFocusChange: (value) => {
                                subs.export(File("auto.srt"), srt.export),
                                player.setSubtitleTrack(
                                    SubtitleTrack.uri("auto.srt")),
                              },
                            )),
                            SizedBox(
                              width: width * 0.03,
                              height: width * 0.03,
                              child: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    setState(() {
                                      savedSubs.add(subs[i]);
                                      subs.edit(i, (_) => false);
                                      if (savedSubs.length == 100) {
                                        savedSubs.removeAt(0);
                                      }
                                    });
                                  }),
                            ),
                            SizedBox(
                              width: width * 0.008,
                              height: width * 0.008,
                            ),
                          ],
                        )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
