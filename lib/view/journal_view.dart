import 'package:flutter/material.dart';

import '../util/time_format.dart';

import '../model/types.dart';
import '../model/store.dart';

import 'collapsible_card.dart';
import 'date_range_selector.dart';
import 'text_edit_dialog.dart';

class JournalView extends StatefulWidget {
  const JournalView({required this.db, Key? key}) : super(key: key);
  final DataStore db;

  @override
  _JournalViewState createState() => _JournalViewState();
}

class _JournalViewState extends State<JournalView> {
  bool _isLoading = true;
  bool _isShowingSearchResults = false;

  List<JournalRecord> _entries = [];

  final _searchCtrl = TextEditingController();

  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    widget.db.findAllJournalRecords().then((res) {
      _entries.addAll(res);
      setState(() => _isLoading = false);
    });
  }

  Widget _paddedTimeChip(DateTime? time) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Chip(
          label: Text("${formatTime(time)}, "
              "${formatDate(time)}")));

  @override
  Widget build(BuildContext context) {
    var searchBar = TextField(
      decoration: InputDecoration(
        hintText: "Search journal",
        border: const OutlineInputBorder(),
        suffixIcon: _searchCtrl.text.isEmpty
            ? const Icon(Icons.search_outlined)
            : IconButton(
                icon: const Icon(Icons.clear_outlined, color: Colors.purple),
                onPressed: () async {
                  _searchCtrl.clear();
                  _entries =
                      await widget.db.findAllJournalRecords(_selectedRange);
                  setState(() {
                    _isShowingSearchResults = false;
                  });
                },
              ),
      ),
      controller: _searchCtrl,
      onChanged: (s) async {
        _isShowingSearchResults = s.isNotEmpty;
        try {
          _entries = await widget.db.findAllJournalRecords(_selectedRange, s);
          setState(() {});
        } catch (e) {
          // Do nothing, likely a half-written advanced search
        }
      },
    );
    var paddedSearchBar = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: searchBar,
    );
    var pickDateRangeButton = DateRangeSelector(onChange: (range) async {
      _selectedRange = range;
      _entries = await widget.db
          .findAllJournalRecords(_selectedRange, _searchCtrl.text);
      setState(() {});
    });

    var addNewRecordButton = FloatingActionButton(
      child: const Icon(Icons.add),
      backgroundColor: Colors.green,
      onPressed: () async {
        var now = DateTime.now();
        var text = await showDialog<String>(
          context: context,
          builder: (context) => TextEditDialog(
            initialText: "",
            textLabel: "Journal Entry",
            title: "Add Record",
            leading: _paddedTimeChip(now),
          ),
        );
        if (text == null || text.isEmpty) return;
        var record = JournalRecord(entry: text, time: now);
        await widget.db.saveJournalRecord(record);
        setState(() => _entries.insert(0, record));
      },
    );
    var paddedButtonRow = Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            pickDateRangeButton,
          ],
        ));
    Widget recordsList = _isLoading
        ? const Text("Loading...")
        : ListView.builder(
            shrinkWrap: true,
            itemCount: _entries.length,
            itemBuilder: (context, i) => CollapsibleCard(
                  // Key should be different when showing search results
                  // otherwise the cards may remain expanded
                  // after clearing search term
                  key: Key("${_entries[i].id}_$_isShowingSearchResults"),
                  initiallyCollapsed: !_isShowingSearchResults,
                  title: Text(
                      formatDate(_entries[i].time) +
                          "; " +
                          formatTime(_entries[i].time),
                      style: const TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold)),
                  content: Row(children: [
                    Expanded(child: Text(_entries[i].entry, softWrap: true)),
                  ]),
                  actions:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      child: const Text("EDIT"),
                      onPressed: () async {
                        var entryText = await showDialog<String>(
                            context: context,
                            builder: (context) => TextEditDialog(
                                initialText: _entries[i].entry,
                                title: "Editing Journal Record",
                                leading: _paddedTimeChip(_entries[i].time)));
                        if (entryText == null) return;
                        _entries[i].entry = entryText;
                        await widget.db.updateJournalRecord(_entries[i]);
                        setState(() {});
                      },
                    ),
                    TextButton(
                      child: const Text("DELETE",
                          style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        await widget.db.deleteJournalRecord(_entries[i]);
                        setState(() => _entries.removeAt(i));
                      },
                    ),
                  ]),
                ));
    return Scaffold(
        appBar: AppBar(
          title: const Text("Journal"),
        ),
        floatingActionButton:
            (_searchCtrl.text.isEmpty && _selectedRange == null)
                ? addNewRecordButton
                : null,
        body: ListView(children: [
          paddedSearchBar,
          paddedButtonRow,
          recordsList,
        ]));
  }
}
