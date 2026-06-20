import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// --- 정렬 방식 정의 ---
enum JournalSortType {
  createdAt,         // 기록 생성일 순
  recentlyUpdated,   // 최근 업데이트 순
  title,             // 작품 이름 순
  entryCount,        // 기록 개수 순
}

// --- 데이터 및 전역 변수 ---
Map<String, Map<String, List<String>>> globalWorkData = {
  '영상물': {'영화': ['가타카'], '드라마': ['사랑의 불시착'], '애니메이션': ['사이코패스', '리제로'], '기타': []},
  '공연': {'연극': [], '뮤지컬': [], '기타': []},
  '책': {'소설': ['비행운', '프로젝트 헤일메리', '바텐더'], '인문학': [], '에세이': [], '시집': [], '만화': [], '기타': []},
  '디지털': {'웹툰': ['전자오락수호대', '오사카환상선'], '웹소설': ['괴담에 떨어져도 출근을 해야 하는구나'], '게임': [], '기타': []},
  '기타': {'그 외': []},
};

List<Map<String, dynamic>> journalEntries = [];

// --- 0. 스플래시 스크린 위젯 ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 2초 후 메인 앱 화면으로 전환
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MediaJournalApp()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo, // Indigo 배경
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // D와 다이어리를 형상화한 로고 디자인
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: const Center(
                child: Icon(Icons.menu_book, size: 60, color: Colors.indigo), // 다이어리 아이콘
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'DIAry',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(), // 스플래시 화면이 첫 화면이 됨
  ));
}

class MediaJournalApp extends StatelessWidget {
  const MediaJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIAry',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}


/// --- [메인 내비게이션 관리] ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _onRecordComplete() {
    setState(() {
      _selectedIndex = 0; // '기록 목록' 탭으로 변경
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const JournalListScreen(),
      RecordEditorScreen(onComplete: _onRecordComplete),
      const WorkManagementScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DIAry', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '기록 목록'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '새 기록'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_suggest), label: '작품 관리'),
        ],
      ),
    );
  }
}

/// --- [1. 감상 기록 목록 화면] ---
class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});
  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  JournalSortType _currentSortType = JournalSortType.createdAt; // 기본값: 생성일 순
  String _selectedCategory = '전체'; // 현재 선택된 대분류 필터
  bool _showOnlyBookmarked = false; // 추가: 북마크 필터 상태

  // 대분류명에 따른 아이콘 매핑 함수 (통일성 보장)
  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '영상물':
        return Icons.movie_outlined;
      case '공연':
        return Icons.theater_comedy_outlined;
      case '책':
        return Icons.menu_book_outlined;
      case '디지털':
        return Icons.devices_outlined;
      case '기타':
      default:
        return Icons.more_horiz_outlined; // 아이콘 영역에 표시될 etc. 대용 아이콘
    }
  }

  // 문자열을 DateTime으로 안전하게 변환하는 헬퍼 함수
  DateTime _getParsedDate(String? dateStr) {
    if (dateStr == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(dateStr) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  // 카테고리 필터 버튼 위젯 빌더
  Widget _buildCategoryButton(String category, {IconData? icon, String? textLabel}) {
    final bool isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.indigo.shade50,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: textLabel != null
            ? Text(
          textLabel,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.indigo.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        )
            : Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : Colors.indigo.shade700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. 대분류 및 북마크 필터링 동시 적용
    List<Map<String, dynamic>> displayEntries = journalEntries.where((entry) {
      // 대분류 검사
      bool matchCategory = _selectedCategory == '전체' || entry['mainCat'] == _selectedCategory;
      if (!matchCategory) return false;

      // 북마크 검사
      bool isBookmarked = entry['isBookmarked'] == true;
      if (_showOnlyBookmarked && !isBookmarked) return false;

      return true;
    }).toList();

    // 2. 필터링된 결과물에 정렬 로직 적용
    if (_currentSortType == JournalSortType.createdAt) {
      displayEntries.sort((a, b) {
        DateTime timeA = _getParsedDate(a['date']?.toString());
        DateTime timeB = _getParsedDate(b['date']?.toString());
        return timeA.compareTo(timeB);
      });
    } else if (_currentSortType == JournalSortType.recentlyUpdated) {
      displayEntries.sort((a, b) {
        DateTime getLatestDate(Map<String, dynamic> entry) {
          List replies = entry['replies'] ?? [];
          if (replies.isEmpty) return _getParsedDate(entry['date']?.toString());
          return _getParsedDate(replies.last['date']?.toString());
        }
        return getLatestDate(b).compareTo(getLatestDate(a));
      });
    } else if (_currentSortType == JournalSortType.title) {
      displayEntries.sort((a, b) {
        String titleA = a['title'] ?? '';
        String titleB = b['title'] ?? '';

        int getPriority(String s) {
          if (s.isEmpty) return 5;
          int code = s.codeUnitAt(0);
          if (code >= 48 && code <= 57) return 2;
          if ((code >= 0xAC00 && code <= 0xD7A3) || (code >= 0x3130 && code <= 0x318F)) return 3;
          if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) return 4;
          return 1;
        }

        int priorityA = getPriority(titleA);
        int priorityB = getPriority(titleB);

        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        } else {
          if (priorityA == 4) {
            return titleA.toLowerCase().compareTo(titleB.toLowerCase());
          }
          return titleA.compareTo(titleB);
        }
      });
    } else if (_currentSortType == JournalSortType.entryCount) {
      displayEntries.sort((a, b) {
        int countA = 1 + (a['replies'] as List).length;
        int countB = 1 + (b['replies'] as List).length;
        int compareCount = countB.compareTo(countA);

        if (compareCount == 0) {
          DateTime timeA = _getParsedDate(a['date']?.toString());
          DateTime timeB = _getParsedDate(b['date']?.toString());
          return timeA.compareTo(timeB);
        }
        return compareCount;
      });
    }

    return Column(
      children: [
        // 상단 필터 및 정렬 바
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 좌측: 카테고리 필터 버튼 그룹
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryButton('전체', textLabel: 'ALL'),
                      _buildCategoryButton('영상물', icon: _getCategoryIcon('영상물')),
                      _buildCategoryButton('공연', icon: _getCategoryIcon('공연')),
                      _buildCategoryButton('책', icon: _getCategoryIcon('책')),
                      _buildCategoryButton('디지털', icon: _getCategoryIcon('디지털')),
                      _buildCategoryButton('기타', textLabel: 'etc.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 우측: 북마크 필터 토글 및 정렬 UI
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 북마크 모아보기 토글 버튼
                  IconButton(
                    icon: Icon(
                      _showOnlyBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _showOnlyBookmarked ? Colors.amber : Colors.grey.shade400,
                    ),
                    tooltip: _showOnlyBookmarked ? '전체 기록 보기' : '북마크만 보기',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _showOnlyBookmarked = !_showOnlyBookmarked;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.sort, size: 18, color: Colors.indigo),
                  const SizedBox(width: 4),
                  DropdownButton<JournalSortType>(
                    value: _currentSortType,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 14, color: Colors.indigo, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
                    items: const [
                      DropdownMenuItem(value: JournalSortType.createdAt, child: Text('기록 생성일 순')),
                      DropdownMenuItem(value: JournalSortType.recentlyUpdated, child: Text('최근 업데이트 순')),
                      DropdownMenuItem(value: JournalSortType.title, child: Text('작품 이름 순')),
                      DropdownMenuItem(value: JournalSortType.entryCount, child: Text('기록 개수 순')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _currentSortType = val);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        // 리스트 영역
        Expanded(
          child: journalEntries.isEmpty
              ? const Center(child: Text('아직 등록된 기록이 없습니다.'))
              : displayEntries.isEmpty
              ? Center(
            child: Text(
              _showOnlyBookmarked
                  ? '조건에 맞는 북마크된 기록이 없습니다.'
                  : '해당 분류에 등록된 기록이 없습니다.',
              style: const TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: displayEntries.length,
            itemBuilder: (context, index) {
              final item = displayEntries[index];
              final int threadCount = 1 + (item['replies'] as List).length;
              final bool isBookmarked = item['isBookmarked'] ?? false; // 북마크 여부 확인

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: item['imagePath'] != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(File(item['imagePath']), width: 50, height: 50, fit: BoxFit.cover),
                  )
                      : Icon(
                    _getCategoryIcon(item['mainCat']),
                    size: 40,
                    color: Colors.indigo.shade400,
                  ),
                  // 수정: 제목 부분은 깔끔하게 텍스트만 남김
                  title: Text(
                    item['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${item['mainCat']} > ${item['subCat']}'),

                  // 수정: 북마크 버튼과 배지를 우측 trailing 영역으로 묶어 수직 중앙 정렬 맞춤
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. 북마크 아이콘 버튼
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? Colors.amber : Colors.grey.shade400,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            item['isBookmarked'] = !isBookmarked;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      // 2. 기존 스레드 배지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.forum_outlined, size: 16, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Text(
                              '$threadCount',
                              style: const TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ThreadDetailScreen(entry: item)),
                    );
                    setState(() {}); // 돌아왔을 때 상태 갱신
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// --- [2. 기록 에디터 화면] ---
class RecordEditorScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const RecordEditorScreen({super.key, required this.onComplete});

  @override
  State<RecordEditorScreen> createState() => _RecordEditorScreenState();
}

class _RecordEditorScreenState extends State<RecordEditorScreen> {
  String? _selectedMain, _selectedSub, _selectedTitle;
  File? _image;
  final picker = ImagePicker();
  final TextEditingController _contentController = TextEditingController();

  Future getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '대분류', border: OutlineInputBorder()),
                  value: _selectedMain,
                  items: globalWorkData.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (val) => setState(() { _selectedMain = val; _selectedSub = null; _selectedTitle = null; }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '소분류', border: OutlineInputBorder()),
                  value: _selectedSub,
                  items: (_selectedMain == null) ? [] : globalWorkData[_selectedMain]!.keys.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (val) => setState(() { _selectedSub = val; _selectedTitle = null; }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: '작품명', border: OutlineInputBorder()),
            value: _selectedTitle,
            items: (_selectedMain == null || _selectedSub == null) ? [] : globalWorkData[_selectedMain]![_selectedSub]!.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
            onChanged: (val) => setState(() => _selectedTitle = val),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(onPressed: getImage, icon: const Icon(Icons.add_a_photo), label: const Text('이미지 첨부')),
          if (_image != null) Padding(padding: const EdgeInsets.only(top: 10), child: Image.file(_image!, height: 150)),
          const SizedBox(height: 15),
          TextField(controller: _contentController, maxLines: 5, decoration: const InputDecoration(hintText: '감상을 남겨주세요.', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: () async {
              if (_selectedTitle != null && _contentController.text.isNotEmpty) {
                final newEntry = {
                  'mainCat': _selectedMain!,
                  'subCat': _selectedSub!,
                  'title': _selectedTitle!,
                  'content': _contentController.text,
                  'imagePath': _image?.path,
                  // 정합성을 위해 ISO 8601 포맷으로 저장
                  'date': DateTime.now().toIso8601String(),
                  'replies': [],
                };

                journalEntries.add(newEntry);

                setState(() {
                  _selectedMain = null; _selectedSub = null; _selectedTitle = null;
                  _image = null; _contentController.clear();
                });

                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ThreadDetailScreen(entry: newEntry)),
                );

                widget.onComplete();
              }
            },
            child: const Text('기록 시작하기'),
          ),
        ],
      ),
    );
  }
}

/// --- [3. 작품 관리 화면] ---
class WorkManagementScreen extends StatefulWidget {
  const WorkManagementScreen({super.key});

  @override
  State<WorkManagementScreen> createState() => _WorkManagementScreenState();
}

class _WorkManagementScreenState extends State<WorkManagementScreen> {
  String _selectedMainCat = '전체';
  String _selectedSubCat = '전체';
  final TextEditingController _newWorkController = TextEditingController();

  @override
  void dispose() {
    _newWorkController.dispose();
    super.dispose();
  }

  // 1. 등록된 작품 삭제 프로세스 (기록 여부 검증 및 팝업 출력)
  void _deleteWork(Map<String, String> work) {
    final String mainCat = work['mainCat']!;
    final String subCat = work['subCat']!;
    final String title = work['title']!;

    // 이미 등록된 감상 기록(journalEntries)이 있는지 확인
    bool hasEntries = journalEntries.any((entry) =>
    entry['title'] == title &&
        entry['mainCat'] == mainCat &&
        entry['subCat'] == subCat);

    if (hasEntries) {
      // 이미 기록이 존재하는 작품인 경우 삭제 불가 팝업 노출
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('삭제 불가', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: const Text('기록이 있는 작품은 삭제할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      // 기록이 없는 경우 정상 삭제 진행 팝업 노출
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('작품 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('정말 삭제하시겠습니까?\n삭제된 작품명은 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  globalWorkData[mainCat]?[subCat]?.remove(title);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('작품이 정상적으로 삭제되었습니다.')),
                );
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  // 2. 등록된 작품의 이름 수정 (기록 목록의 작품명 동시 수정 조치)
  void _editWorkName(Map<String, String> work) {
    final String mainCat = work['mainCat']!;
    final String subCat = work['subCat']!;
    final String oldTitle = work['title']!;

    final TextEditingController editController = TextEditingController(text: oldTitle);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작품명 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: '새로운 작품 이름을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final String newTitle = editController.text.trim();
              if (newTitle.isEmpty) return;

              if (newTitle == oldTitle) {
                Navigator.pop(context);
                return;
              }

              setState(() {
                // 2-a. 전역 데이터베이스(globalWorkData) 명칭 수정
                final List<String>? list = globalWorkData[mainCat]?[subCat];
                if (list != null) {
                  int index = list.indexOf(oldTitle);
                  if (index != -1) {
                    list[index] = newTitle;
                  }
                }

                // 2-b. 이미 등록된 기록(journalEntries) 리스트에 나타나는 이름도 동시 수정 반영
                for (var entry in journalEntries) {
                  if (entry['title'] == oldTitle &&
                      entry['mainCat'] == mainCat &&
                      entry['subCat'] == subCat) {
                    entry['title'] = newTitle;
                  }
                }
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('작품 이름이 수정되었습니다.')),
              );
            },
            child: const Text('수정', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 새로운 작품을 추가하는 기본 헬퍼 기능
  void _addNewWork() {
    if (_selectedMainCat == '전체' || _selectedSubCat == '전체') return;
    final String title = _newWorkController.text.trim();
    if (title.isEmpty) return;

    if (globalWorkData[_selectedMainCat]?[_selectedSubCat]?.contains(title) ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 존재하는 작품명입니다.')),
      );
      return;
    }

    setState(() {
      globalWorkData[_selectedMainCat]?[_selectedSubCat]?.add(title);
      _newWorkController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 3, 3-1. 분류 선택 여부에 따른 작품 리스트 다이내믹 필터링
    final List<Map<String, String>> displayedWorks = [];

    globalWorkData.forEach((mainCat, subMap) {
      // 대분류 필터 체크 ('전체'가 아니면서 일치하지 않으면 패스)
      if (_selectedMainCat != '전체' && mainCat != _selectedMainCat) return;

      subMap.forEach((subCat, workList) {
        // 소분류 필터 체크 ('전체'가 아니면서 일치하지 않으면 패스)
        if (_selectedSubCat != '전체' && subCat != _selectedSubCat) return;

        for (var work in workList) {
          displayedWorks.add({
            'mainCat': mainCat,
            'subCat': subCat,
            'title': work,
          });
        }
      });
    });

    // 선택된 대분류에 기반한 소분류 드롭다운 옵션 목록 실시간 추출
    final List<String> subCatOptions = ['전체'];
    if (_selectedMainCat != '전체') {
      subCatOptions.addAll(globalWorkData[_selectedMainCat]?.keys ?? []);
    }

    return Scaffold(
      body: Column(
        children: [
          // 상단 카테고리 필터 조작 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50.withOpacity(0.3),
            child: Column(
              children: [
                Row(
                  children: [
                    // 대분류 드롭다운
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMainCat,
                        decoration: const InputDecoration(
                          labelText: '대분류',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: ['전체', ...globalWorkData.keys].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedMainCat = val!;
                            _selectedSubCat = '전체'; // 대분류가 바뀌면 소분류는 무조건 초기화
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 소분류 드롭다운
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubCat,
                        decoration: const InputDecoration(
                          labelText: '소분류',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: subCatOptions.map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSubCat = val!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // 특정 소분류까지 완벽히 지정된 경우 인라인 등록 필드 제공
                if (_selectedMainCat != '전체' && _selectedSubCat != '전체') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newWorkController,
                          decoration: InputDecoration(
                            hintText: '$_selectedSubCat에 등록할 신규 작품명',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addNewWork,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                        child: const Text('추가'),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
          // 작품 리스트 뷰 영역
          Expanded(
            child: displayedWorks.isEmpty
                ? const Center(child: Text('해당 조건에 부합하는 작품이 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: displayedWorks.length,
              itemBuilder: (context, index) {
                final work = displayedWorks[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(
                      work['title']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    // 4. 등록된 작품명 밑에 작은 회색 글씨로 해당 작품의 대분류와 소분류 정보 표시
                    subtitle: Text(
                      '${work['mainCat']} - ${work['subCat']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                          onPressed: () => _editWorkName(work),
                          tooltip: '이름 수정',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteWork(work),
                          tooltip: '작품 삭제',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// --- [2. 감상 기록 상세 및 스레드 화면] ---
class ThreadDetailScreen extends StatefulWidget {
  final Map<String, dynamic> entry;
  const ThreadDetailScreen({super.key, required this.entry});

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _selectedReplyImagePath;

  // 수정을 위한 상태 관리 변수
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();
  String? _editImagePath;

  @override
  void initState() {
    super.initState();
    // 진입 시 가장 마지막 스레드로 자동 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  // 작성 시간을 날짜와 시간, 분 단위까지 표시하는 함수
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    DateTime? dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // 최상단/최하단 이동 기능 함수
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  // 이미지 첨부 및 수정 헬퍼 함수
  Future<void> _pickImage({required bool isEdit}) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isEdit) {
          _editImagePath = image.path;
        } else {
          _selectedReplyImagePath = image.path;
        }
      });
    }
  }

  // 스레드 삭제 확인 팝업창 출력을 위한 함수
  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스레드 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('정말 삭제하시겠습니까?\n삭제된 기록은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (index == 0) {
                  journalEntries.remove(widget.entry);
                  Navigator.pop(context);
                } else {
                  List replies = widget.entry['replies'] ?? [];
                  replies.removeAt(index - 1);
                }
              });
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 새 스레드 등록
  void _addReply() {
    if (_replyController.text.trim().isEmpty && _selectedReplyImagePath == null) return;

    setState(() {
      List replies = widget.entry['replies'] ?? [];
      replies.add({
        'date': DateTime.now().toString(),
        'content': _replyController.text.trim(),
        'imagePath': _selectedReplyImagePath,
      });
      _replyController.clear();
      _selectedReplyImagePath = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // 수정 내용 임베딩 저장
  void _saveEdit(int index) {
    setState(() {
      if (index == 0) {
        widget.entry['content'] = _editController.text.trim();
        widget.entry['imagePath'] = _editImagePath;
      } else {
        List replies = widget.entry['replies'] ?? [];
        replies[index - 1]['content'] = _editController.text.trim();
        replies[index - 1]['imagePath'] = _editImagePath;
      }
      _editingIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    List replies = widget.entry['replies'] ?? [];
    int totalCount = 1 + replies.length;

    // 추가: 화면 높이의 1/3을 계산하여 입력창의 최대 높이로 설정
    final double maxInputHeight = MediaQuery.of(context).size.height / 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry['title'] ?? '기록 상세', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 28),
            onPressed: _scrollToTop,
            tooltip: '최상단으로 이동',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            onPressed: () => _scrollToBottom(animated: true),
            tooltip: '최하단으로 이동',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 스레드 타임라인 리스트뷰 영역
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                final bool isFirst = index == 0;

                final String? imagePath = isFirst ? widget.entry['imagePath'] : replies[index - 1]['imagePath'];
                final String content = isFirst ? (widget.entry['content'] ?? '') : (replies[index - 1]['content'] ?? '');
                final String? rawDate = isFirst ? widget.entry['date'] : replies[index - 1]['date'];
                final String displayDate = _formatDate(rawDate);

                final bool isCurrentEditing = _editingIndex == index;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isFirst)
                      const Padding(
                        padding: EdgeInsets.only(left: 20),
                        child: SizedBox(height: 14, child: VerticalDivider(thickness: 2, color: Colors.indigo)),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: isFirst ? Colors.indigo : Colors.grey.shade400,
                          radius: 12,
                          child: Icon(
                              isFirst ? Icons.star : Icons.subdirectory_arrow_right,
                              size: 14,
                              color: Colors.white
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isFirst ? Colors.indigo.shade50.withOpacity(0.4) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isFirst ? Colors.indigo.shade100 : Colors.grey.shade200),
                            ),
                            child: isCurrentEditing
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _editController,
                                  maxLines: null,
                                  decoration: const InputDecoration(
                                    hintText: '내용을 수정하세요...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(10),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_editImagePath != null)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(File(_editImagePath!), height: 120, fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black54,
                                          radius: 14,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                            onPressed: () => setState(() => _editImagePath = null),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _pickImage(isEdit: true),
                                      icon: const Icon(Icons.image_outlined, size: 18),
                                      label: const Text('이미지 변경'),
                                    ),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => setState(() => _editingIndex = null),
                                          child: const Text('취소', style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _saveEdit(index),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                                          child: const Text('저장'),
                                        ),
                                      ],
                                    )
                                  ],
                                )
                              ],
                            )
                                : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (isFirst)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2.0),
                                              child: Text(
                                                  '${widget.entry['mainCat']} > ${widget.entry['subCat']}',
                                                  style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)
                                              ),
                                            ),
                                          Text(displayDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              _editingIndex = index;
                                              _editController.text = content;
                                              _editImagePath = imagePath;
                                            });
                                          },
                                          tooltip: '수정',
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showDeleteDialog(index),
                                          tooltip: '삭제',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (imagePath != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(File(imagePath))
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                      content,
                                      style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // 하단: 새로운 스레드를 추가하는 입력 필드 및 폼
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedReplyImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(File(_selectedReplyImagePath!), width: 60, height: 60, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedReplyImagePath = null),
                                  child: const CircleAvatar(backgroundColor: Colors.black54, radius: 10, child: Icon(Icons.close, size: 12, color: Colors.white)),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end, // 아이콘을 텍스트 하단부에 맞춤
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: Colors.indigo),
                        onPressed: () => _pickImage(isEdit: false),
                      ),
                      // 수정: TextField를 ConstrainedBox로 감싸 최대 높이를 지정
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxInputHeight,
                          ),
                          child: Scrollbar(
                            child: TextField(
                              controller: _replyController,
                              decoration: const InputDecoration(
                                hintText: '추가 스레드를 남겨보세요...',
                                border: InputBorder.none,
                              ),
                              maxLines: null, // 내용에 따라 길어지게 설정
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.indigo),
                        onPressed: _addReply,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}