import 'package:flutter/material.dart';
import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:io';

class WordViewerScreen extends StatefulWidget {
  final String? filePath;

  const WordViewerScreen({Key? key, this.filePath}) : super(key: key);

  @override
  _WordViewerScreenState createState() => _WordViewerScreenState();
}

class _WordViewerScreenState extends State<WordViewerScreen> {
  String? _currentFilePath;
  String? _currentFileName;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.filePath != null) {
      _loadDocument(widget.filePath!);
    }
  }

  void _loadDocument(String filePath) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentFilePath = filePath;
      _currentFileName = filePath.split('/').last;
    });

    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        backgroundColor: Color(0xFF3498DB),
        elevation: 0,
        title: Text(
          _currentFileName ?? 'Word Viewer',
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
            tooltip: 'Select Word Document',
          ),
        ],
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

    return _buildDocumentViewer();
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
              color: Color(0xFF3498DB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.article,
              size: 50,
              color: Color(0xFF3498DB),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Select a Word Document',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Choose a .doc or .docx file to view\nwith full formatting and layout',
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
              backgroundColor: Color(0xFF3498DB),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Supported formats: DOC, DOCX',
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
            color: Color(0xFF3498DB),
            size: 50.0,
          ),
          SizedBox(height: 20),
          Text(
            'Loading document...',
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
            'Unable to open document',
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
                  backgroundColor: Color(0xFF3498DB),
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
                  foregroundColor: Color(0xFF3498DB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer() {
    if (!File(_currentFilePath!).existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
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
              'The selected file may have been moved or deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: Icon(Icons.folder_open),
              label: Text('Select Another File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3498DB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    try {
      return Container(
        color: Colors.grey[100],
        child: DocxViewer(
          file: File(_currentFilePath!),
        ),
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            SizedBox(height: 16),
            Text(
              'Error loading document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: Icon(Icons.folder_open),
              label: Text('Try Another File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3498DB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }
}