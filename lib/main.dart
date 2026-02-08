import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';

void main() {
  runApp(const ReisebeihilfeApp());
}

class ReisebeihilfeApp extends StatelessWidget {
  const ReisebeihilfeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: UebersichtSeite(),
    );
  }
}

class Zeitraum {
  String titel;
  bool beantragt;
  bool genehmigt;
  bool gezahlt;
  double betrag;

  Zeitraum(
    this.titel, {
    this.beantragt = false,
    this.genehmigt = false,
    this.gezahlt = false,
    this.betrag = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'titel': titel,
        'beantragt': beantragt,
        'genehmigt': genehmigt,
        'gezahlt': gezahlt,
        'betrag': betrag,
      };

  factory Zeitraum.fromJson(Map<String, dynamic> json) => Zeitraum(
        json['titel'],
        beantragt: json['beantragt'],
        genehmigt: json['genehmigt'],
        gezahlt: json['gezahlt'],
        betrag: (json['betrag'] ?? 0).toDouble(),
      );
}


class UebersichtSeite extends StatefulWidget {
  const UebersichtSeite({super.key});

  @override
  State<UebersichtSeite> createState() => _UebersichtSeiteState();
}

class _UebersichtSeiteState extends State<UebersichtSeite> {
  List<Zeitraum> zeitraeume = [];

  @override
  void initState() {
    super.initState();
    _initialisieren();
  }

  Future<void> _initialisieren() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('daten');

    if (data != null) {
      final list = jsonDecode(data) as List;
      zeitraeume = list.map((e) => Zeitraum.fromJson(e)).toList();
    } else {
      zeitraeume = _startListe();
    }
    setState(() {});
  }

  List<Zeitraum> _startListe() {
    final labels = [
      '05.01.2026 – 18.01.2026',
      '19.01.2026 – 01.02.2026',
      '02.02.2026 – 15.02.2026',
      '16.02.2026 – 01.03.2026',
    ];
    return labels.map((e) => Zeitraum(e)).toList();
  }

  Future<void> _speichern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'daten', jsonEncode(zeitraeume.map((e) => e.toJson()).toList()));
  }

  void _resetAlles() {
    for (var z in zeitraeume) {
      z.beantragt = false;
      z.genehmigt = false;
      z.gezahlt = false;
    }
    _speichern();
    setState(() {});
  }

  void _neuerZeitraum() {
    final letzter = zeitraeume.last.titel;
    final teile = letzter.split('–');
    final start = _parse(teile[1].trim());
    final neuStart = start.add(const Duration(days: 1));
    final neuEnde = neuStart.add(const Duration(days: 13));

    zeitraeume.add(
      Zeitraum('${_fmt(neuStart)} – ${_fmt(neuEnde)}'),
    );
    _speichern();
    setState(() {});
  }

  DateTime _parse(String s) {
    final p = s.split('.');
    return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _warnliste() {
    final offen = zeitraeume.where((z) => !z.gezahlt).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Offene Zeiträume'),
        content: SizedBox(
          width: 400,
          child: ListView(
            children: offen.map((z) => Text(z.titel)).toList(),
          ),
        ),
      ),
    );
  }

  void _excelExport() {
  final excel = Excel.createExcel();
  final sheet = excel['Reisebeihilfe'];

  sheet.appendRow([
    TextCellValue('Zeitraum'),
    TextCellValue('Beantragt'),
    TextCellValue('Genehmigt'),
    TextCellValue('Gezahlt'),
    TextCellValue('Betrag (€)'),
  ]);

  for (var z in zeitraeume) {
    sheet.appendRow([
      TextCellValue(z.titel),
      TextCellValue(z.beantragt ? 'Ja' : 'Nein'),
      TextCellValue(z.genehmigt ? 'Ja' : 'Nein'),
      TextCellValue(z.gezahlt ? 'Ja' : 'Nein'),
      TextCellValue(z.betrag.toStringAsFixed(2)),
    ]);
  }

  excel.save(fileName: 'Reisebeihilfe.xlsx');
}


  @override
  Widget build(BuildContext context) {
   final gesamt = zeitraeume.fold<double>(
  0.0,
  (summe, z) => summe + z.betrag,
);

final beantragt = zeitraeume
    .where((z) => z.beantragt)
    .fold<double>(0.0, (s, z) => s + z.betrag);

final gezahlt = zeitraeume
    .where((z) => z.gezahlt)
    .fold<double>(0.0, (s, z) => s + z.betrag);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Reisebeihilfe – Übersicht'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _neuerZeitraum),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetAlles),
          IconButton(icon: const Icon(Icons.warning), onPressed: _warnliste),
          IconButton(
              icon: const Icon(Icons.table_chart),
              onPressed: _excelExport),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Gesamt (€): ${gesamt.toStringAsFixed(2)}'),
Text('Beantragt (€): ${beantragt.toStringAsFixed(2)}'),
Text('Gezahlt (€): ${gezahlt.toStringAsFixed(2)}'),

                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: zeitraeume.map((z) {
                return Card(
                  child: Column(
                    children: [
                      ListTile(title: Text(z.titel)),
                      CheckboxListTile(
                        title: const Text('Beantragt'),
                        value: z.beantragt,
                        onChanged: (v) {
                          z.beantragt = v!;
                          _speichern();
                          setState(() {});
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Genehmigt'),
                        value: z.genehmigt,
                        onChanged: (v) {
                          z.genehmigt = v!;
                          _speichern();
                          setState(() {});
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Gezahlt'),
                        value: z.gezahlt,
                        onChanged: (v) {
                          z.gezahlt = v!;
                          _speichern();
                          setState(() {});
                        },
                      ),
                      Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: TextField(
    keyboardType: TextInputType.number,
    decoration: const InputDecoration(
      labelText: 'Betrag (€)',
    ),
    controller: TextEditingController(
      text: z.betrag == 0 ? '' : z.betrag.toStringAsFixed(2),
    ),
    onChanged: (v) {
      z.betrag = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
      _speichern();
    },
  ),
),

                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
