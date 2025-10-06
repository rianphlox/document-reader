import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:io';

class ExcelViewerScreen extends StatefulWidget {
  final String? filePath;

  const ExcelViewerScreen({Key? key, this.filePath}) : super(key: key);

  @override
  _ExcelViewerScreenState createState() => _ExcelViewerScreenState();
}

class _ExcelViewerScreenState extends State<ExcelViewerScreen> {
  String? _currentFilePath;
  String? _currentFileName;
  bool _isLoading = false;
  String? _errorMessage;
  Excel? _excel;
  List<String> _sheetNames = [];
  int _currentSheetIndex = 0;
  List<List<String>> _sheetData = [];

  @override
  void initState() {
    super.initState();
    if (widget.filePath != null) {
      _loadDocument(widget.filePath!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadDocument(String filePath) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentFilePath = filePath;
      _currentFileName = filePath.split('/').last;
    });

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File not found');
      }

      final bytes = await file.readAsBytes();
      _excel = Excel.decodeBytes(bytes);
      _sheetNames = _excel!.tables.keys.toList();

      if (_sheetNames.isNotEmpty) {
        _loadSheetData(0);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading Excel file: $e';
      });
    }
  }

  void _loadSheetData(int sheetIndex) {
    if (sheetIndex < 0 || sheetIndex >= _sheetNames.length) return;

    final sheetName = _sheetNames[sheetIndex];
    final sheet = _excel!.tables[sheetName]!;
    final List<List<String>> data = [];

    for (var row in sheet.rows) {
      final List<String> rowData = [];
      for (var cell in row) {
        String cellValue = '';
        if (cell != null && cell.value != null) {
          cellValue = cell.value.toString();
        }
        rowData.add(cellValue);
      }
      if (rowData.any((cell) => cell.isNotEmpty)) {
        data.add(rowData);
      }
    }

    setState(() {
      _currentSheetIndex = sheetIndex;
      _sheetData = data;
    });
  }

  Future<void> _pickFile() async {
    // File picker functionality removed for compatibility
    // Documents are already provided through the app's main interface
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF27AE60),
        elevation: 0,
        title: Text(
          _currentFileName ?? 'Excel Viewer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.folder_open, color: Colors.white),
            onPressed: _pickFile,
            tooltip: 'Select Excel File',
          ),
        ],
        bottom: _sheetNames.length > 1
            ? PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: Container(
                  height: 48,
                  color: Colors.white.withOpacity(0.1),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _sheetNames.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentSheetIndex;
                      return GestureDetector(
                        onTap: () => _loadSheetData(index),
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _sheetNames[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Color(0xFF27AE60)
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (_currentFilePath == null) {
      return _buildFilePickerWidget();
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    return _buildSpreadsheetViewer();
  }

  Widget _buildFilePickerWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color(0xFF27AE60).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.grid_on,
              size: 50,
              color: Color(0xFF27AE60),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Select an Excel Spreadsheet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Choose a .xls or .xlsx file to view\nwith data tables and formatting',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: Icon(Icons.folder_open),
            label: Text('Select File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF27AE60),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Supported formats: XLS, XLSX',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCircle(
            color: Color(0xFF27AE60),
            size: 50.0,
          ),
          SizedBox(height: 20),
          Text(
            'Loading spreadsheet...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _currentFileName ?? '',
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

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          SizedBox(height: 20),
          Text(
            'Unable to open spreadsheet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: Icon(Icons.folder_open),
                label: Text('Try Another File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _currentFilePath = null;
                    _currentFileName = null;
                  });
                },
                icon: Icon(Icons.refresh),
                label: Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF27AE60),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetViewer() {
    if (_sheetData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Empty spreadsheet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This spreadsheet contains no data.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          if (_sheetNames.length > 1)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(
                    Icons.grid_on,
                    color: Color(0xFF27AE60),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Sheet: ${_sheetNames[_currentSheetIndex]}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${_sheetData.length} rows × ${_sheetData.isNotEmpty ? _sheetData[0].length : 0} columns',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 16,
                  headingRowColor: MaterialStateProperty.all(
                    Color(0xFF27AE60).withOpacity(0.1),
                  ),
                  dataRowHeight: 56,
                  headingRowHeight: 56,
                  columns: _buildColumns(),
                  rows: _buildRows(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (_sheetData.isEmpty) return [];

    final maxCols = _sheetData[0].length;
    return List.generate(maxCols, (index) {
      String header = _sheetData.isNotEmpty && index < _sheetData[0].length
          ? _sheetData[0][index]
          : String.fromCharCode(65 + index);

      if (header.isEmpty) {
        header = String.fromCharCode(65 + index);
      }

      return DataColumn(
        label: Container(
          constraints: BoxConstraints(minWidth: 100, maxWidth: 200),
          child: Text(
            header,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF27AE60),
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    });
  }

  List<DataRow> _buildRows() {
    if (_sheetData.length <= 1) return [];

    return _sheetData.skip(1).map((rowData) {
      final cells = List.generate(_sheetData[0].length, (colIndex) {
        final cellValue = colIndex < rowData.length ? rowData[colIndex] : '';
        return DataCell(
          Container(
            constraints: BoxConstraints(minWidth: 100, maxWidth: 200),
            child: Text(
              cellValue,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2D3748),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      });

      return DataRow(cells: cells);
    }).toList();
  }
}