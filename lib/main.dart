import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';

import 'package:isar/isar.dart';
import 'package:intl/intl.dart';

part 'main.g.dart';

final saveDateFormat = DateFormat('yMMMMd');

@collection
class DailyMark {
  Id id = Isar.autoIncrement;
  late DateTime date;
  late List<double>
      marks; // For the time being the subjects will be looked up using index in list
  late double totalMarks = 0;
}

final Map<int, String> subjects = {1: "Physics", 2: "Chemistry", 3: "Maths"};

Future<Isar> openIsarInstance() async {
  final dir = await getApplicationDocumentsDirectory();
  await Isar.open([DailyMarkSchema], directory: dir.path, inspector: true);

  return Future.value(Isar.getInstance());
}

String getFormattedDate([DateTime? dateToFormat]) {
  dateToFormat ??= DateTime.now();

  return saveDateFormat.format(dateToFormat);
}

DateTime parseFormattedDate(String formattedDate) {
  // Add error catching
  return saveDateFormat.parse(formattedDate);
}

String calculateChangeInPercent(double originalValue, double changedValue) {
  double changeInValue = changedValue - originalValue;
  double percentageChange = (changeInValue / originalValue) * 100;
  return "${percentageChange.toStringAsFixed(2)}%";
}

Color getValueChangeChange(String valueInPercent) {
  double? valueInNum =
      double.tryParse(valueInPercent.replaceAll(RegExp(r'%'), ''));

  if (valueInNum == null || valueInNum == 0.00) {
    return Colors.white;
  }

  if (valueInNum > 0) {
    return Colors.green.shade800;
  } else {
    return Colors.red.shade800;
  }
}

void main() {
  runApp(const EvalApp());
}

class EvalApp extends StatelessWidget {
  const EvalApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eval You',
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(
            Theme.of(context).textTheme.apply(bodyColor: Colors.white)),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(250, 250, 9, 33),
          primary: const Color.fromARGB(250, 250, 9, 33),
          secondary: const Color.fromARGB(125, 161, 15, 31),
          tertiary: const Color.fromARGB(250, 233, 128, 140),
          background: const Color.fromARGB(250, 13, 4, 5),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePage();
}

class _MyHomePage extends State<MyHomePage> {
  int _daysLeft = 0;

  ValueNotifier<double> habitValueNotifier = ValueNotifier(0);

  Future<Isar> isarDb = openIsarInstance();

  List<FlSpot> graphPoints = [];

  void calculateDaysLeft() {
    setState(() {
      final examDay = DateTime(2024, 4, 1);
      final currentDate = DateTime.now();
      _daysLeft = examDay.difference(currentDate).inDays;
    });
  }

  void getGraphPoints() async {
    const int numOfDaysTosummarize = 5;
    // Get data of last 5 days
    final isar = await isarDb;
    final markEntries = await isar.dailyMarks
        .filter()
        .dateLessThan(DateTime.now(), include: true)
        .and()
        .dateGreaterThan(
            DateTime.now().subtract(const Duration(days: numOfDaysTosummarize)),
            include: true)
        .findAll();
    // Set date as 'x' and mark as 'y'
    graphPoints.clear();

    double index = 0;
    late DateTime firstDate;
    int numberOfDaysMissed = 0;

    for (DailyMark eachDayEntry in markEntries) {
      if (index == 0) {
        firstDate = eachDayEntry.date;
        index++;
      } else {
        while (eachDayEntry.date.difference(firstDate).inDays > index) {
          numberOfDaysMissed++;
          index++;
        }
      }
      FlSpot singlePoint = FlSpot(index,
          eachDayEntry.marks.reduce((value, element) => value + element));
      graphPoints.add(singlePoint);
      index++;
    }

    habitValueNotifier.value =
        ((numOfDaysTosummarize - numberOfDaysMissed) / numOfDaysTosummarize) *
            100;

    setState(() {});
    return;
  }

  late List<Widget> subjectInfoWidget = [];

  @override
  void initState() {
    super.initState();
    updateMarkSummary();
  }

  void updateMarkSummary() async {
    final isar = await isarDb;
    final todaysMarks = await isar.dailyMarks
        .filter()
        .dateEqualTo(parseFormattedDate(getFormattedDate()))
        .findFirst();
    final previousDayMarks = await isar.dailyMarks
        .filter()
        .dateEqualTo(parseFormattedDate(
            getFormattedDate(DateTime.now().subtract(const Duration(days: 1)))))
        .findFirst();

    subjectInfoWidget.clear();

    if (todaysMarks == null) {
      for (String subjectName in subjects.values) {
        Row subjectInfo = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(subjectName), const Text('-')],
        );

        subjectInfoWidget.add(subjectInfo);
      }
      getGraphPoints();

      setState(() {});

      return;
    }

    int currentIndex = 0;

    for (double todaysSubjectMark in todaysMarks.marks) {
      Row subjectInfo = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            subjects[currentIndex + 1]!,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300),
          ),
          Row(
            children: [
              Text('${todaysSubjectMark.toString()}  ',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  )),
              previousDayMarks == null
                  ? const Text('',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ))
                  : Text(
                      calculateChangeInPercent(
                          previousDayMarks.marks[currentIndex],
                          todaysSubjectMark),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: getValueChangeChange(calculateChangeInPercent(
                              previousDayMarks.marks[currentIndex],
                              todaysSubjectMark))),
                    )
            ],
          )
        ],
      );

      currentIndex++;

      subjectInfoWidget.add(subjectInfo);
    }
    getGraphPoints();

    setState(() {});

    return;
  }

  void storeTodaysMark(int subjectId, double mark) async {
    final isar = await isarDb;
    final todaysMarks = await isar.dailyMarks
        .filter()
        .dateEqualTo(parseFormattedDate(getFormattedDate()))
        .findFirst();

    List<double> updatingMarks = [0, 0, 0];

    if (todaysMarks == null) {
      updatingMarks[subjectId - 1] = mark;

      final newMarkEntry = DailyMark()
        ..date = parseFormattedDate(getFormattedDate())
        ..marks = updatingMarks;

      await isar.writeTxn(() async {
        await isar.dailyMarks.put(newMarkEntry);
      });

      updateMarkSummary();
      return;
    }

    updatingMarks = todaysMarks.marks;
    updatingMarks[subjectId - 1] = mark;

    todaysMarks.marks = updatingMarks;
    await isar.writeTxn(() async {
      await isar.dailyMarks.put(todaysMarks);
    });

    updateMarkSummary();

    return;
  }

  void markEntryDialog(BuildContext context) async {
    showDialog(
        context: context,
        builder: (context) => SimpleDialog(
              alignment: Alignment.center,
              backgroundColor: Theme.of(context).primaryColor,
              title: Text(getFormattedDate()),
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("Physics"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(45, 8, 45, 20),
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^(\d+)?\.?\d{0,2}'))
                      ],
                      onSubmitted: (value) =>
                          storeTodaysMark(1, double.tryParse(value)!),
                    ),
                  ),
                  const Text("Chemistry"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(45, 8, 45, 20),
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^(\d+)?\.?\d{0,2}'))
                      ],
                      onSubmitted: (value) =>
                          storeTodaysMark(2, double.tryParse(value)!),
                    ),
                  ),
                  const Text("Maths"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(45, 8, 45, 20),
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^(\d+)?\.?\d{0,2}'))
                      ],
                      onSubmitted: (value) =>
                          storeTodaysMark(3, double.tryParse(value)!),
                    ),
                  ),
                ])
              ],
            ));

    setState(() {});

    return;
  }

  @override
  Widget build(BuildContext context) {
    calculateDaysLeft();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GradientText(
                  '$_daysLeft',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                  ),
                  gradient:
                      LinearGradient(begin: Alignment.bottomLeft, colors: [
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.primary,
                  ]),
                ),
                const Text("Days left",
                    style: TextStyle(fontSize: 20)) // FONT SIZE UPDATE NEEDED
              ],
            ),
          ),
          Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: const BorderRadius.all(Radius.circular(20))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Text(
                      "Habit Status",
                      style: TextStyle(fontSize: 20),
                    ),
                    SimpleCircularProgressBar(
                      size: 80,
                      mergeMode: true,
                      progressStrokeWidth: 25,
                      backStrokeWidth: 25,
                      backColor: Theme.of(context).colorScheme.secondary,
                      progressColors: [Theme.of(context).primaryColor],
                      startAngle: 225,
                      valueNotifier: habitValueNotifier,
                      onGetText: (double value) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        );
                      },
                    ),
                  ],
                ),
              )),
          Expanded(
              flex: 1,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          getFormattedDate(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        OutlinedButton(
                            onPressed: () => markEntryDialog(context),
                            child: const Icon(
                              Icons.playlist_add,
                              color: Colors.white,
                            ))
                      ],
                    ),
                    Padding(
                        padding: const EdgeInsets.only(left: 40, right: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: subjectInfoWidget,
                        ))
                  ])),
          Expanded(
            flex: 1,
            child: LineChart(LineChartData(
              gridData: const FlGridData(
                  show: true, horizontalInterval: 100, drawVerticalLine: false),
              lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white.withOpacity(0.2))),
              titlesData: const FlTitlesData(
                bottomTitles: AxisTitles(
                    axisNameSize: 14,
                    drawBelowEverything: false,
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                rightTitles: AxisTitles(
                    axisNameSize: 16,
                    sideTitles: SideTitles(showTitles: true, reservedSize: 35)),
                leftTitles: AxisTitles(
                    axisNameSize: 16,
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(
                    axisNameSize: 16,
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.7), width: 2))),
              lineBarsData: [
                LineChartBarData(
                    spots: graphPoints, color: Theme.of(context).primaryColor)
              ],
              minY: 0,
              maxY: 300,
            )),
          ),
        ]),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}
