import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/photo_filter_service.dart';

class PhotoFilterScreen extends StatefulWidget {
  final String imagePath;

  const PhotoFilterScreen({super.key, required this.imagePath});

  @override
  State<PhotoFilterScreen> createState() => _PhotoFilterScreenState();
}

class _PhotoFilterScreenState extends State<PhotoFilterScreen> {
  PhotoFilter _selectedFilter = PhotoFilter.none;
  bool _isApplying = false;
  bool _isGeneratingPreview = false;
  Uint8List? _previewBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Aplicar Filtro'),
        actions: [
          if (_isApplying)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _applyFilter,
              child: const Text(
                'APLICAR',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: _isGeneratingPreview
                  ? const Center(child: CircularProgressIndicator())
                  : (_previewBytes != null
                        ? InteractiveViewer(
                            child: Image.memory(
                              _previewBytes!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : InteractiveViewer(
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.contain,
                            ),
                          )),
            ),
          ),
          Container(
            height: 160,
            color: Colors.grey[900],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: PhotoFilter.values.length,
              itemBuilder: (context, index) {
                final filter = PhotoFilter.values[index];
                final isSelected = _selectedFilter == filter;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = filter;
                    });

                    _generatePreviewFor(filter);
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: FutureBuilder(
                              future: PhotoFilterService.instance
                                  .getFilterPreview(widget.imagePath, filter),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.data != null) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  );
                                }
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            PhotoFilterService.instance.getFilterName(filter),
                            style: TextStyle(
                              color: isSelected ? Colors.blue : Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

  @override
  void initState() {
    super.initState();

    _generatePreviewFor(_selectedFilter);
  }

  Future<void> _generatePreviewFor(PhotoFilter filter) async {
    setState(() {
      _isGeneratingPreview = true;
    });
    try {
      final bytes = await PhotoFilterService.instance.getFilterPreview(
        widget.imagePath,
        filter,
        width: 800,
      );
      if (mounted) {
        setState(() {
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewBytes = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPreview = false;
        });
      }
    }
  }

  Future<void> _applyFilter() async {
    if (_isApplying) return;

    setState(() => _isApplying = true);

    try {
      final filteredPath = await PhotoFilterService.instance.applyFilter(
        widget.imagePath,
        _selectedFilter,
      );

      // Upload será feito ao salvar/atualizar a tarefa

      if (mounted) {
        Navigator.pop(context, filteredPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar filtro: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isApplying = false);
      }
    }
  }
}
