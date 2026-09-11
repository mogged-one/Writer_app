import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WriterApp());
}

class WriterApp extends StatelessWidget {
  const WriterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Писатель',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          iconTheme: IconThemeData(color: Color(0xFFE0E0E0)),
        ),
      ),
      home: const MainWriterScreen(),
    );
  }
}

class Book {
  String id;
  String title;
  String content;

  Book({required this.id, required this.title, required this.content});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'content': content};

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      content: json['content'],
    );
  }
}

class ChapterMarker {
  final String title;
  final int offset;

  ChapterMarker({required this.title, required this.offset});
}

class MainWriterScreen extends StatefulWidget {
  const MainWriterScreen({super.key});

  @override
  State<MainWriterScreen> createState() => _MainWriterScreenState();
}

class _MainWriterScreenState extends State<MainWriterScreen> {
  final TextEditingController _textController = TextEditingController();
  final UndoHistoryController _undoController = UndoHistoryController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();

  List<Book> _books = [];
  int _currentBookIndex = 0;

  List<ChapterMarker> _chapters = [];
  int _currentChapterIndex = 0;

  double _fontSize = 18.0;
  Timer? _debounceTimer;

  final List<String> _specialSymbols = ['«', '—', '„', '“', '”'];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _textController.addListener(_onTextControllerChanged);
  }

  void _onTextControllerChanged() {
    _parseChapters();
  }

  void _updateTextController(String text) {
    _textController.value = TextEditingValue(
      text: text,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? booksJson = prefs.getString('saved_books');

    if (booksJson != null) {
      final List<dynamic> decoded = jsonDecode(booksJson);
      _books = decoded.map((item) => Book.fromJson(item)).toList();
    }

    if (_books.isEmpty) {
      _books.add(Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Моя книга',
        content: 'Глава 1. ',
      ));
    }

    _currentBookIndex = prefs.getInt('current_book_index') ?? 0;
    if (_currentBookIndex >= _books.length) {
      _currentBookIndex = 0;
    }

    _fontSize = prefs.getDouble('font_size') ?? 18.0;

    _updateTextController(_books[_currentBookIndex].content);
    _parseChapters();
  }

  void _parseChapters() {
    final text = _textController.text;
    final RegExp regExp = RegExp(r'^Глава\s+\d+.*$', multiLine: true, caseSensitive: false);
    final Iterable<RegExpMatch> matches = regExp.allMatches(text);

    List<ChapterMarker> markers = [];
    for (final match in matches) {
      markers.add(ChapterMarker(
        title: match.group(0) ?? 'Глава',
        offset: match.start,
      ));
    }

    if (markers.isEmpty) {
      markers.add(ChapterMarker(title: 'Начало', offset: 0));
    }

    if (mounted) {
      setState(() {
        _chapters = markers;
        if (_currentChapterIndex >= _chapters.length) {
          _currentChapterIndex = _chapters.length - 1;
        }
        if (_currentChapterIndex < 0) {
          _currentChapterIndex = 0;
        }
      });
    }
  }

  Future<void> _saveBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_books.map((b) => b.toJson()).toList());
    await prefs.setString('saved_books', encoded);
    await prefs.setInt('current_book_index', _currentBookIndex);
    await prefs.setDouble('font_size', _fontSize);
  }

  void _onTextChanged(String text) {
    if (_books.isNotEmpty && _currentBookIndex < _books.length) {
      _books[_currentBookIndex].content = text;
      
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        _saveBooks();
      });
    }
  }

  void _selectBook(int index) {
    _debounceTimer?.cancel();
    _saveBooks();

    setState(() {
      _currentBookIndex = index;
      _updateTextController(_books[index].content);
      _currentChapterIndex = 0;
    });
    Navigator.pop(context);
  }

  void _addBook() {
    _debounceTimer?.cancel();
    _saveBooks();

    setState(() {
      final newBookNumber = _books.length + 1;
      final newBook = Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Книга $newBookNumber',
        content: 'Глава 1. ',
      );
      _books.add(newBook);
      _currentBookIndex = _books.length - 1;
      _updateTextController(newBook.content);
      _currentChapterIndex = 0;
    });
    _saveBooks();
    Navigator.pop(context);
  }

  void _deleteBook(int index) {
    if (_books.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас должна оставаться хотя бы одна книга')),
      );
      return;
    }

    _debounceTimer?.cancel();
    setState(() {
      _books.removeAt(index);
      if (_currentBookIndex >= _books.length) {
        _currentBookIndex = _books.length - 1;
      }
      _updateTextController(_books[_currentBookIndex].content);
      _currentChapterIndex = 0;
    });
    _saveBooks();
  }

  Future<void> _exportToTxt() async {
    if (_books.isEmpty) return;
    // Export functionality disabled due to environment limitations
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Экспорт недоступен в текущем окружении')),
    );
  }

  void _requestFocus() {
    if (!_textFieldFocusNode.hasFocus) {
      _textFieldFocusNode.requestFocus();
    }
  }

  void _addNewChapterCheckpoint() {
    final newChapterNum = _chapters.length + 1;
    final textToInsert = 'Глава $newChapterNum. ';

    final text = _textController.text;
    final selection = _textController.selection;
    int start = selection.start < 0 ? text.length : selection.start;
    int end = selection.end < 0 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, textToInsert);
    final newCursorOffset = start + textToInsert.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );

    _onTextChanged(newText);
    _requestFocus();
  }

  void _scrollToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;

    setState(() {
      _currentChapterIndex = index;
    });

    final offset = _chapters[index].offset;
    final textLength = _textController.text.length;
    if (textLength == 0 || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    double targetPosition = (offset / textLength) * maxScroll - 40;
    if (targetPosition < 0) targetPosition = 0;

    _scrollController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _insertSymbol(String symbol) {
    final text = _textController.text;
    final selection = _textController.selection;

    int start = selection.start < 0 ? text.length : selection.start;
    int end = selection.end < 0 ? text.length : selection.end;

    String textToInsert = symbol;
    int cursorOffsetShift = symbol.length;

    if (symbol == '«') {
      textToInsert = '«»';
      cursorOffsetShift = 1;
    }

    final newText = text.replaceRange(start, end, textToInsert);

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + cursorOffsetShift),
    );

    _onTextChanged(newText);
    _requestFocus();
  }

  void _showRenameDialog() {
    final TextEditingController titleController = TextEditingController(text: _books[_currentBookIndex].title);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF252525),
          title: const Text('Название книги', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Введите название',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty) {
                  setState(() => _books[_currentBookIndex].title = newTitle);
                  _saveBooks();
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Сохранить', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252525),
              title: const Text('Настройки', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Размер шрифта: ${_fontSize.round()} pt',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _fontSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 20,
                    activeColor: Colors.blueAccent,
                    inactiveColor: Colors.grey[700],
                    label: '${_fontSize.round()}',
                    onChanged: (double value) {
                      setDialogState(() {
                        _fontSize = value;
                      });
                      setState(() {
                        _fontSize = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Пример текста',
                      style: TextStyle(color: const Color(0xFFE0E0E0), fontSize: _fontSize),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _saveBooks();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Готово', style: TextStyle(color: Colors.blueAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChapterSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredChapters = _chapters.where((c) {
              return c.title.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Список глав', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Поиск главы...',
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Color(0xFF252525),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setSheetState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredChapters.length,
                      itemBuilder: (context, index) {
                        final chapter = filteredChapters[index];
                        return ListTile(
                          title: Text(chapter.title, style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            final originalIndex = _chapters.indexOf(chapter);
                            Navigator.pop(context);
                            _scrollToChapter(originalIndex);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.removeListener(_onTextControllerChanged);
    _textController.dispose();
    _undoController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBookTitle = _books.isNotEmpty ? _books[_currentBookIndex].title : 'Книга';
    final currentChapterTitle = (_chapters.isNotEmpty && _currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length)
        ? _chapters[_currentChapterIndex].title
        : 'Начало';

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _showRenameDialog,
              child: Text(currentBookTitle, style: const TextStyle(fontSize: 16)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _currentChapterIndex > 0
                      ? () => _scrollToChapter(_currentChapterIndex - 1)
                      : null,
                ),
                GestureDetector(
                  onTap: _showChapterSearchSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      currentChapterTitle,
                      style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _currentChapterIndex < _chapters.length - 1
                      ? () => _scrollToChapter(_currentChapterIndex + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF252525),
            onSelected: (value) {
              if (value == 'Настройки') {
                _showSettingsDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'Настройки', 
                child: Text('Настройки', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF121212)),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.library_books, color: Colors.blueAccent),
                    SizedBox(width: 12),
                    Text(
                      'Мои Книги',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _books.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentBookIndex;
                  return ListTile(
                    leading: Icon(
                      Icons.book,
                      color: isSelected ? Colors.blueAccent : Colors.grey,
                    ),
                    title: Text(
                      _books[index].title,
                      style: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                      onPressed: () => _deleteBook(index),
                    ),
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF252525),
                    onTap: () => _selectBook(index),
                  );
                },
              ),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.greenAccent),
              title: const Text(
                'Экспортировать в .TXT',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _exportToTxt();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_photos, color: Colors.blueAccent),
              title: const Text(
                'Создать книгу',
                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              onTap: _addBook,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  controller: _textController,
                  undoController: _undoController,
                  scrollController: _scrollController,
                  focusNode: _textFieldFocusNode,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _onTextChanged,
                  style: TextStyle(
                    color: const Color(0xFFE0E0E0),
                    fontSize: _fontSize,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Начните писать книгу...',
                    hintStyle: TextStyle(color: Color(0xFF555555)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Container(
              height: 48,
              color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  ValueListenableBuilder<UndoHistoryValue>(
                    valueListenable: _undoController,
                    builder: (context, value, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo, size: 20),
                            color: value.canUndo ? Colors.blueAccent : Colors.grey,
                            onPressed: value.canUndo ? () {
                              _undoController.undo();
                              _requestFocus();
                            } : null,
                            tooltip: 'Отменить',
                          ),
                          IconButton(
                            icon: const Icon(Icons.redo, size: 20),
                            color: value.canRedo ? Colors.blueAccent : Colors.grey,
                            onPressed: value.canRedo ? () {
                              _undoController.redo();
                              _requestFocus();
                            } : null,
                            tooltip: 'Повторить',
                          ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 22),
                    onPressed: _addNewChapterCheckpoint,
                    tooltip: 'Вставить новую главу',
                  ),
                  const VerticalDivider(width: 1, color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _specialSymbols.length,
                      itemBuilder: (context, index) {
                        final symbol = _specialSymbols[index];
                        return InkWell(
                          onTap: () => _insertSymbol(symbol),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            child: Text(
                              symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
