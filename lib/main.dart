import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

// Real Document Model
class DocumentModel {
  final String id;
  final String name;
  final String path;
  final String type;
  final int size;
  final DateTime dateModified;
  final DateTime dateAdded;
  bool isFavorite;
  int currentPage;
  
  DocumentModel({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.dateModified,
    required this.dateAdded,
    this.isFavorite = false,
    this.currentPage = 0,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'size': size,
      'dateModified': dateModified.millisecondsSinceEpoch,
      'dateAdded': dateAdded.millisecondsSinceEpoch,
      'isFavorite': isFavorite,
      'currentPage': currentPage,
    };
  }
  
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      type: json['type'],
      size: json['size'],
      dateModified: DateTime.fromMillisecondsSinceEpoch(json['dateModified']),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(json['dateAdded']),
      isFavorite: json['isFavorite'] ?? false,
      currentPage: json['currentPage'] ?? 0,
    );
  }
}

// Real File Scanner Service - Fast and Efficient
class FileSystemService {
  static final List<String> _supportedExtensions = [
    'pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx', 'xls', 'xlsx', 'rtf', 'epub'
  ];
  
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
      
      return statuses[Permission.storage]?.isGranted == true ||
             statuses[Permission.manageExternalStorage]?.isGranted == true;
    }
    return true;
  }
  
  static Future<List<DocumentModel>> scanForDocuments() async {
    List<DocumentModel> documents = [];
    
    try {
      print('Starting fast document scan...');
      
      // Only scan the most important directories - no recursive scanning
      final primaryDirs = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents', 
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/Telegram/Telegram Documents',
      ];
      
      // Scan primary directories (non-recursive)
      for (String dirPath in primaryDirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          print('Scanning: $dirPath');
          await _scanDirectoryFlat(dir, documents);
        }
      }
      
      // Quick scan of root directory for common document types (non-recursive)
      final rootDir = Directory('/storage/emulated/0');
      if (await rootDir.exists()) {
        print('Quick scanning root directory...');
        await _scanDirectoryFlat(rootDir, documents);
      }
      
    } catch (e) {
      print('Error in scanForDocuments: $e');
    }
    
    // Remove duplicates and sort
    final uniqueDocuments = _removeDuplicates(documents);
    
    print('Scan completed!');
    print('Total documents found: ${uniqueDocuments.length}');
    _printFileTypeBreakdown(uniqueDocuments);
    
    return uniqueDocuments;
  }
  
  static Future<void> _scanDirectoryFlat(Directory dir, List<DocumentModel> documents) async {
    try {
      // Only scan files in this directory - NO recursion
      await for (FileSystemEntity entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          await _processFile(entity, documents);
        }
      }
    } catch (e) {
      print('Cannot access directory ${dir.path}: $e');
    }
  }
  
  static Future<void> _processFile(File file, List<DocumentModel> documents) async {
    try {
      final fileName = file.path.split('/').last;
      final nameParts = fileName.split('.');
      
      if (nameParts.length < 2) return; // No extension
      
      final extension = nameParts.last.toLowerCase();
      print('Processing file: $fileName with extension: .$extension');
      
      // Check if it's a supported document type or image
      if (_supportedExtensions.contains(extension) || 
          ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
        
        final stat = await file.stat();
        
        // Skip very small files for documents (but keep images)
        if (!['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension) && 
            stat.size < 1024) {
          print('Skipping small file: $fileName (${stat.size} bytes)');
          return;
        }
        
        final document = DocumentModel(
          id: file.path.hashCode.toString(),
          name: fileName,
          path: file.path,
          type: extension, // This is the key - make sure extension is stored correctly
          size: stat.size,
          dateModified: stat.modified,
          dateAdded: stat.accessed,
        );
        
        documents.add(document);
        print('Added: ${document.name} as type: ${document.type}');
      }
    } catch (e) {
      print('Error processing file ${file.path}: $e');
    }
  }
  
  static List<DocumentModel> _removeDuplicates(List<DocumentModel> documents) {
    final uniqueDocuments = <String, DocumentModel>{};
    for (var doc in documents) {
      uniqueDocuments[doc.path] = doc;
    }
    
    final result = uniqueDocuments.values.toList();
    result.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    
    return result;
  }
  
  static void _printFileTypeBreakdown(List<DocumentModel> documents) {
    final typeCounts = <String, int>{};
    for (var doc in documents) {
      final type = doc.type.toUpperCase();
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    
    print('=== FILE TYPE BREAKDOWN ===');
    typeCounts.entries.forEach((entry) {
      print('${entry.key}: ${entry.value} files');
    });
    print('===========================');
  }
  
  static Future<DocumentModel?> addDocumentFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'scanned_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPath = '${appDir.path}/$fileName';
        
        await File(image.path).copy(newPath);
        final stat = await File(newPath).stat();
        
        return DocumentModel(
          id: newPath.hashCode.toString(),
          name: fileName,
          path: newPath,
          type: 'jpg',
          size: stat.size,
          dateModified: stat.modified,
          dateAdded: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error capturing document: $e');
    }
    return null;
  }
  
  static Future<DocumentModel?> addDocumentFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'imported_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPath = '${appDir.path}/$fileName';
        
        await File(image.path).copy(newPath);
        final stat = await File(newPath).stat();
        
        return DocumentModel(
          id: newPath.hashCode.toString(),
          name: fileName,
          path: newPath,
          type: 'jpg',
          size: stat.size,
          dateModified: stat.modified,
          dateAdded: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error importing from gallery: $e');
    }
    return null;
  }
  
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
  
  static String getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return '📄';
      case 'doc':
      case 'docx': return '📝';
      case 'ppt':
      case 'pptx': return '📊';
      case 'xls':
      case 'xlsx': return '📈';
      case 'txt': 
      case 'rtf': return '📃';
      case 'epub': return '📖';
      case 'jpg':
      case 'jpeg':
      case 'png': return '🖼️';
      default: return '📋';
    }
  }
  
  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Document Provider with Real Data
class DocumentProvider extends ChangeNotifier {
  List<DocumentModel> _documents = [];
  bool _isLoading = false;
  String _searchQuery = '';
  
  List<DocumentModel> get documents => _documents;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  
  List<DocumentModel> get recentDocuments {
    final sorted = List<DocumentModel>.from(_documents);
    sorted.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return sorted.take(10).toList();
  }
  
  List<DocumentModel> get favoriteDocuments {
    return _documents.where((doc) => doc.isFavorite).toList();
  }
  
  List<DocumentModel> get filteredDocuments {
    if (_searchQuery.isEmpty) return _documents;
    return _documents.where((doc) => 
      doc.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }
  
  // Get documents by type
  List<DocumentModel> getDocumentsByType(String type) {
    print('Getting documents for type: $type'); // Debug logging
    print('Total documents: ${_documents.length}'); // Debug logging
    
    List<DocumentModel> result;
    switch (type) {
      case 'PDF':
        result = _documents.where((doc) {
          final matches = doc.type.toLowerCase() == 'pdf';
          if (matches) print('Found PDF: ${doc.name}');
          return matches;
        }).toList();
        break;
      case 'DOC':
        result = _documents.where((doc) {
          final matches = ['doc', 'docx'].contains(doc.type.toLowerCase());
          if (matches) print('Found DOC: ${doc.name}');
          return matches;
        }).toList();
        break;
      case 'PPT':
        result = _documents.where((doc) {
          final matches = ['ppt', 'pptx'].contains(doc.type.toLowerCase());
          if (matches) print('Found PPT: ${doc.name}');
          return matches;
        }).toList();
        break;
      case 'XLS':
        result = _documents.where((doc) {
          final matches = ['xls', 'xlsx'].contains(doc.type.toLowerCase());
          if (matches) print('Found XLS: ${doc.name}');
          return matches;
        }).toList();
        break;
      case 'TXT':
        result = _documents.where((doc) {
          final matches = ['txt', 'rtf'].contains(doc.type.toLowerCase());
          if (matches) print('Found TXT: ${doc.name}');
          return matches;
        }).toList();
        break;
      case 'Images':
        result = _documents.where((doc) {
          final matches = ['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(doc.type.toLowerCase());
          if (matches) print('Found Image: ${doc.name}');
          return matches;
        }).toList();
        break;
      default:
        result = _documents;
    }
    
    print('Found ${result.length} documents for type $type'); // Debug logging
    return result;
  }
  
  // Calculate real storage usage
  double get totalStorageUsed {
    return _documents.fold(0.0, (sum, doc) => sum + doc.size) / (1024 * 1024 * 1024);
  }
  
  Future<void> loadDocuments() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Request permissions
      await FileSystemService.requestPermissions();
      
      // Scan for documents
      _documents = await FileSystemService.scanForDocuments();
      
      // Load favorites from preferences
      await _loadFavorites();
      
    } catch (e) {
      print('Error loading documents: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> addDocument(DocumentModel document) async {
    _documents.insert(0, document);
    await _saveFavorites();
    notifyListeners();
  }
  
  Future<void> toggleFavorite(String documentId) async {
    final index = _documents.indexWhere((doc) => doc.id == documentId);
    if (index != -1) {
      _documents[index].isFavorite = !_documents[index].isFavorite;
      await _saveFavorites();
      notifyListeners();
    }
  }
  
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  Future<void> refreshDocuments() async {
    await loadDocuments();
  }
  
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString('favorites') ?? '[]';
      final favoriteIds = List<String>.from(json.decode(favoritesJson));
      
      for (var doc in _documents) {
        doc.isFavorite = favoriteIds.contains(doc.id);
      }
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }
  
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = _documents
          .where((doc) => doc.isFavorite)
          .map((doc) => doc.id)
          .toList();
      
      await prefs.setString('favorites', json.encode(favoriteIds));
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }
}

void main() {
  runApp(DocumentReaderApp());
}

class DocumentReaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DocumentProvider(),
      child: MaterialApp(
        title: 'All Document',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          primaryColor: Color(0xFFFF6B35),
          fontFamily: 'SF Pro Display',
          scaffoldBackgroundColor: Color(0xFFF8F9FA),
        ),
        home: MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    HomeScreen(),
    FavoritesScreen(),
    RecentScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }
  
  Future<void> _loadDocuments() async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    await provider.loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFFF6B35),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Recent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF6B35),
        elevation: 0,
        title: Text(
          'All Document',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () => _navigateToSearch(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _refreshDocuments(context),
          ),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, documentProvider, child) {
          if (documentProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Scanning for documents...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => documentProvider.refreshDocuments(),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStorageCard(documentProvider),
                  SizedBox(height: 24),
                  
                  Text(
                    'Documents',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildDocumentGrid(context, documentProvider),
                  SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Files',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RecentScreen()),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(color: Color(0xFFFF6B35)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildRecentFiles(context, documentProvider),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showImportOptions(context),
        backgroundColor: Color(0xFFFF6B35),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStorageCard(DocumentProvider provider) {
    final totalDocs = provider.documents.length;
    final totalSizeGB = provider.totalStorageUsed;
    final maxStorageGB = 128.0; // You can get actual device storage if needed
    final usedPercentage = (totalSizeGB / maxStorageGB * 100).clamp(0.0, 100.0);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${totalSizeGB.toStringAsFixed(2)}GB/${maxStorageGB.toInt()}GB',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Documents storage • $totalDocs files',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalSizeGB / maxStorageGB,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ],
            ),
          ),
          SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: totalSizeGB / maxStorageGB,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Center(
                  child: Text(
                    '${usedPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentGrid(BuildContext context, DocumentProvider provider) {
    print('Building document grid with ${provider.documents.length} total documents'); // Debug logging
    
    final documentTypes = [
      {
        'name': 'All Files',
        'icon': Icons.folder,
        'color': Color(0xFF4A90E2),
        'count': provider.documents.length
      },
      {
        'name': 'PDF',
        'icon': Icons.description,
        'color': Color(0xFFE74C3C),
        'count': provider.getDocumentsByType('PDF').length
      },
      {
        'name': 'DOC',
        'icon': Icons.article,
        'color': Color(0xFF3498DB),
        'count': provider.getDocumentsByType('DOC').length
      },
      {
        'name': 'PPT',
        'icon': Icons.present_to_all,
        'color': Color(0xFFF39C12),
        'count': provider.getDocumentsByType('PPT').length
      },
      {
        'name': 'XLS',
        'icon': Icons.grid_on,
        'color': Color(0xFF27AE60),
        'count': provider.getDocumentsByType('XLS').length
      },
      {
        'name': 'Images',
        'icon': Icons.image,
        'color': Color(0xFF9B59B6),
        'count': provider.getDocumentsByType('Images').length
      },
    ];

    // Debug: Print file types found
    Map<String, int> typeCounts = {};
    for (var doc in provider.documents) {
      typeCounts[doc.type] = (typeCounts[doc.type] ?? 0) + 1;
    }
    print('File types found: $typeCounts');

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: documentTypes.length,
      itemBuilder: (context, index) {
        final type = documentTypes[index];
        return GestureDetector(
          onTap: () => _navigateToDocumentList(context, type['name'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (type['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type['icon'] as IconData,
                    color: type['color'] as Color,
                    size: 28,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  type['name'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${type['count']} files',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentFiles(BuildContext context, DocumentProvider provider) {
    final recentFiles = provider.recentDocuments.take(3).toList();
    
    if (recentFiles.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12),
            Text(
              'No documents found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap + to add documents or refresh to scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: recentFiles.map((file) {
        return GestureDetector(
          onTap: () => _openDocument(context, file),
          child: Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B35).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      FileSystemService.getFileIcon(file.type),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${FileSystemService.formatFileSize(file.size)} • ${FileSystemService.formatTimeAgo(file.dateModified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    file.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: file.isFavorite ? Color(0xFFFF6B35) : Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: () {
                    Provider.of<DocumentProvider>(context, listen: false)
                        .toggleFavorite(file.id);
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _navigateToSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchScreen()),
    );
  }

  void _navigateToDocumentList(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentListScreen(category: category),
      ),
    );
  }

  void _openDocument(BuildContext context, DocumentModel document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(document: document),
      ),
    );
  }

  void _refreshDocuments(BuildContext context) {
    Provider.of<DocumentProvider>(context, listen: false).refreshDocuments();
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ImportOptionsSheet(),
    );
  }
}

// Continue with other screens using real data...
class ImportOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add Document',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImportOption(
                context,
                Icons.camera_alt,
                'Camera',
                Color(0xFFE74C3C),
                () => _importFromCamera(context),
              ),
              _buildImportOption(
                context,
                Icons.photo_library,
                'Gallery',
                Color(0xFF9B59B6),
                () => _importFromGallery(context),
              ),
              _buildImportOption(
                context,
                Icons.refresh,
                'Scan',
                Color(0xFF27AE60),
                () => _scanForDocuments(context),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildImportOption(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  void _importFromCamera(BuildContext context) async {
    Navigator.pop(context);
    final document = await FileSystemService.addDocumentFromCamera();
    if (document != null) {
      Provider.of<DocumentProvider>(context, listen: false).addDocument(document);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document captured successfully!'),
          backgroundColor: Color(0xFF27AE60),
        ),
      );
    }
  }

  void _importFromGallery(BuildContext context) async {
    Navigator.pop(context);
    final document = await FileSystemService.addDocumentFromGallery();
    if (document != null) {
      Provider.of<DocumentProvider>(context, listen: false).addDocument(document);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document imported successfully!'),
          backgroundColor: Color(0xFF27AE60),
        ),
      );
    }
  }

  void _scanForDocuments(BuildContext context) async {
    Navigator.pop(context);
    await Provider.of<DocumentProvider>(context, listen: false).refreshDocuments();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document scan completed!'),
        backgroundColor: Color(0xFF27AE60),
      ),
    );
  }
}

// Real Document Viewer
class DocumentViewerScreen extends StatefulWidget {
  final DocumentModel document;
  
  DocumentViewerScreen({required this.document});

  @override
  _DocumentViewerScreenState createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _showAnnotationTools = false;
  Color _selectedAnnotationColor = Colors.yellow;
  int currentPage = 0;
  int totalPages = 0;
  bool isReady = false;
  
  final List<Color> _annotationColors = [
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
    Colors.red,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4A90E2),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.document.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer<DocumentProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  widget.document.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
                onPressed: () {
                  provider.toggleFavorite(widget.document.id);
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareDocument(),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildDocumentViewer(),
          
          if (_showAnnotationTools)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _annotationColors.map((color) {
                    bool isSelected = color == _selectedAnnotationColor;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAnnotationColor = color;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomIcon(Icons.bookmark, 'Bookmark'),
            _buildBottomIcon(Icons.text_fields, 'Text'),
            _buildBottomIcon(Icons.color_lens, 'Annotate', onTap: () {
              setState(() {
                _showAnnotationTools = !_showAnnotationTools;
              });
            }),
            _buildBottomIcon(Icons.edit, 'Signature'),
            _buildBottomIcon(Icons.share, 'Share', onTap: _shareDocument),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentViewer() {
    if (!File(widget.document.path).existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'File not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'The file may have been moved or deleted.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (widget.document.type.toLowerCase() == 'pdf') {
      return PDFView(
        filePath: widget.document.path,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: true,
        pageSnap: true,
        defaultPage: currentPage,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        onRender: (pages) {
          setState(() {
            totalPages = pages!;
            isReady = true;
          });
        },
        onError: (error) {
          print('PDF Error: $error');
        },
        onPageError: (page, error) {
          print('Page $page Error: $error');
        },
        onViewCreated: (PDFViewController controller) {
          // PDF controller ready
        },
        onLinkHandler: (String? uri) {
          print('Link: $uri');
        },
        onPageChanged: (int? page, int? total) {
          setState(() {
            currentPage = page ?? 0;
            totalPages = total ?? 0;
          });
        },
      );
    } else if (['jpg', 'jpeg', 'png'].contains(widget.document.type.toLowerCase())) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(
            File(widget.document.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cannot load image',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    } else if (['txt', 'rtf'].contains(widget.document.type.toLowerCase())) {
      return FutureBuilder<String>(
        future: File(widget.document.path).readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error reading file',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Text(
              snapshot.data ?? 'Empty file',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF2D3748),
              ),
            ),
          );
        },
      );
    } else {
      // For other file types
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  FileSystemService.getFileIcon(widget.document.type),
                  style: TextStyle(fontSize: 48),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              widget.document.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'File type: ${widget.document.type.toUpperCase()}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Size: ${FileSystemService.formatFileSize(widget.document.size)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _shareDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Open with External App'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBottomIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Color(0xFF4A90E2),
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF4A90E2),
            ),
          ),
        ],
      ),
    );
  }

  void _shareDocument() {
    Share.shareXFiles([XFile(widget.document.path)], text: 'Check out this document: ${widget.document.name}');
  }
}

// Additional screens with real data...
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF6B35),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search documents...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            Provider.of<DocumentProvider>(context, listen: false)
                .updateSearchQuery(value);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              _searchController.clear();
              Provider.of<DocumentProvider>(context, listen: false)
                  .updateSearchQuery('');
            },
          ),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, child) {
          final searchResults = provider.filteredDocuments;
          
          if (provider.searchQuery.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Search for documents',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Found ${provider.documents.length} documents on your device',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          if (searchResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No documents found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final document = searchResults[index];
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        FileSystemService.getFileIcon(document.type),
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    document.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${FileSystemService.formatFileSize(document.size)} • ${document.type.toUpperCase()}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentViewerScreen(document: document),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Continue with other screens...
class DocumentListScreen extends StatelessWidget {
  final String category;
  
  DocumentListScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF6B35),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, child) {
          final documents = provider.getDocumentsByType(category);
          print('DocumentListScreen: ${documents.length} documents for category $category'); // Debug logging

          if (documents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No $category files found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scan your device to find more documents',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerScreen(document: document),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            FileSystemService.getFileIcon(document.type),
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${FileSystemService.formatFileSize(document.size)} • ${FileSystemService.formatTimeAgo(document.dateModified)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          document.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: document.isFavorite ? Color(0xFFFF6B35) : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () {
                          provider.toggleFavorite(document.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF6B35),
        elevation: 0,
        title: Text(
          'Favorite Files',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, child) {
          final favoriteDocuments = provider.favoriteDocuments;
          
          if (favoriteDocuments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No favorite files',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on any document to add it to favorites',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: favoriteDocuments.length,
            itemBuilder: (context, index) {
              final document = favoriteDocuments[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerScreen(document: document),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            FileSystemService.getFileIcon(document.type),
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${FileSystemService.formatFileSize(document.size)} • ${FileSystemService.formatTimeAgo(document.dateModified)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.favorite,
                          color: Color(0xFFFF6B35),
                          size: 20,
                        ),
                        onPressed: () {
                          provider.toggleFavorite(document.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RecentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF6B35),
        elevation: 0,
        title: Text(
          'Recent Files',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, child) {
          final recentDocuments = provider.recentDocuments;
          
          if (recentDocuments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No recent files',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Documents will appear here as you open them',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: recentDocuments.length,
            itemBuilder: (context, index) {
              final document = recentDocuments[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerScreen(document: document),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            FileSystemService.getFileIcon(document.type),
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${FileSystemService.formatFileSize(document.size)} • Modified ${FileSystemService.formatTimeAgo(document.dateModified)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          document.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: document.isFavorite ? Color(0xFFFF6B35) : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () {
                          provider.toggleFavorite(document.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF6B35),
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildStatsSection(provider),
              SizedBox(height: 20),
              _buildSettingsSection('App Actions', [
                _buildSettingsItem(
                  Icons.refresh, 
                  'Scan for Documents', 
                  'Found ${provider.documents.length} documents',
                  onTap: () => _scanDocuments(context),
                ),
                _buildSettingsItem(Icons.folder_open, 'Open App Directory', ''),
              ]),
              SizedBox(height: 20),
              _buildSettingsSection('Reading Preferences', [
                _buildSettingsItem(Icons.color_lens, 'Theme', 'Auto (System)'),
                _buildSettingsItem(Icons.text_fields, 'Font Size', 'Medium'),
                _buildSettingsItem(Icons.brightness_6, 'Reading Mode', 'Day Mode'),
              ]),
              SizedBox(height: 20),
              _buildSettingsSection('Storage & Sync', [
                _buildSettingsItem(Icons.storage, 'Storage Used', '${provider.totalStorageUsed.toStringAsFixed(2)} GB'),
                _buildSettingsItem(Icons.favorite, 'Favorites', '${provider.favoriteDocuments.length} files'),
                _buildSettingsItem(Icons.access_time, 'Recent Files', '${provider.recentDocuments.length} files'),
              ]),
              SizedBox(height: 20),
              _buildSettingsSection('About', [
                _buildSettingsItem(Icons.info, 'Version', '1.0.0'),
                _buildSettingsItem(Icons.privacy_tip, 'Privacy Policy', ''),
                _buildSettingsItem(Icons.description, 'Terms of Service', ''),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsSection(DocumentProvider provider) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Total Files', '${provider.documents.length}', Icons.folder),
              ),
              Expanded(
                child: _buildStatItem('PDF Files', '${provider.getDocumentsByType('PDF').length}', Icons.description),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Favorites', '${provider.favoriteDocuments.length}', Icons.favorite),
              ),
              Expanded(
                child: _buildStatItem('Storage', '${provider.totalStorageUsed.toStringAsFixed(1)} GB', Icons.storage),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Color(0xFFFF6B35).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Color(0xFFFF6B35),
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFFFF6B35).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Color(0xFFFF6B35),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2D3748),
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: onTap != null ? Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ) : null,
      onTap: onTap,
    );
  }

  void _scanDocuments(BuildContext context) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    await provider.refreshDocuments();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document scan completed! Found ${provider.documents.length} documents.'),
        backgroundColor: Color(0xFF27AE60),
      ),
    );
  }
}