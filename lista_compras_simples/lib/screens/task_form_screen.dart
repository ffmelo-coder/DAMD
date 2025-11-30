import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker.dart';
import '../screens/photo_filter_screen.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  String _categoryId = 'default';
  bool _completed = false;
  bool _isLoading = false;
  DateTime? _dueDate;
  TimeOfDay? _reminderTime;
  List<Category> _categories = [];

  String? _photoPath;
  List<String> _photosPaths = [];
  double? _latitude;
  double? _longitude;
  String? _locationName;
  List<Map<String, dynamic>> _locationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _categoryId = widget.task!.categoryId;
      _dueDate = widget.task!.dueDate;

      _photoPath = widget.task!.photoPath;
      _photosPaths = widget.task!.photosPaths ?? [];
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
      _locationHistory = widget.task!.locationHistory ?? [];

      if (widget.task!.reminderTime != null) {
        _reminderTime = TimeOfDay.fromDateTime(widget.task!.reminderTime!);
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await DatabaseService.instance.readAllCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final photoPath = await CameraService.instance.takePicture(context);

    if (photoPath != null && mounted) {
      final shouldApplyFilter = await _showFilterOption();

      String finalPhotoPath = photoPath;
      if (shouldApplyFilter == true && mounted) {
        final filteredPath = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoFilterScreen(imagePath: photoPath),
          ),
        );
        if (filteredPath != null) {
          finalPhotoPath = filteredPath;
        }
      }

      if (mounted) {
        setState(() {
          _photoPath = finalPhotoPath;
          if (!_photosPaths.contains(finalPhotoPath)) {
            _photosPaths.add(finalPhotoPath);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Foto capturada!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<bool?> _showFilterOption() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar Filtro?'),
        content: const Text('Deseja aplicar um filtro à foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NÃO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SIM'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final photoPath = await CameraService.instance.pickFromGallery();

    if (photoPath != null && mounted) {
      final shouldApplyFilter = await _showFilterOption();

      String finalPhotoPath = photoPath;
      if (shouldApplyFilter == true && mounted) {
        final filteredPath = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoFilterScreen(imagePath: photoPath),
          ),
        );
        if (filteredPath != null) {
          finalPhotoPath = filteredPath;
        }
      }

      if (mounted) {
        setState(() {
          _photoPath = finalPhotoPath;
          if (!_photosPaths.contains(finalPhotoPath)) {
            _photosPaths.add(finalPhotoPath);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ Foto selecionada!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickMultipleFromGallery() async {
    final photos = await CameraService.instance.pickMultipleFromGallery();

    if (photos.isNotEmpty && mounted) {
      setState(() {
        for (final photo in photos) {
          if (!_photosPaths.contains(photo)) {
            _photosPaths.add(photo);
          }
        }
        if (_photoPath == null && _photosPaths.isNotEmpty) {
          _photoPath = _photosPaths.first;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🖼️ ${photos.length} foto(s) selecionada(s)!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removePhoto(String photoPath) {
    setState(() {
      _photosPaths.remove(photoPath);
      if (_photoPath == photoPath) {
        _photoPath = _photosPaths.isNotEmpty ? _photosPaths.first : null;
      }
    });
  }

  void _viewPhoto(String photoPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(photoPath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationPicker() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: LocationPicker(
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            initialAddress: _locationName,
            onLocationSelected: (lat, lon, address) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _locationName = address;
                _addToLocationHistory(lat, lon, address);
              });
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📍 Localização selecionada!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _addToLocationHistory(double lat, double lon, String? address) {
    final historyEntry = {
      'latitude': lat,
      'longitude': lon,
      'address': address ?? 'Endereço desconhecido',
      'timestamp': DateTime.now().toIso8601String(),
    };
    _locationHistory.add(historyEntry);
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('📍 Localização removida')));
  }

  Future<void> _saveTask() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      DateTime? reminderDateTime;
      if (_reminderTime != null && _dueDate != null) {
        reminderDateTime = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
          _reminderTime!.hour,
          _reminderTime!.minute,
        );
      }

      if (widget.task == null) {
        final newTask = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          categoryId: _categoryId,
          dueDate: _dueDate,
          reminderTime: reminderDateTime,
          photoPath: _photoPath,
          photosPaths: _photosPaths.isNotEmpty ? _photosPaths : null,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          locationHistory: _locationHistory.isNotEmpty
              ? _locationHistory
              : null,
        );
        await DatabaseService.instance.create(newTask);

        if (reminderDateTime != null &&
            reminderDateTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleTaskReminder(newTask);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          categoryId: _categoryId,
          dueDate: _dueDate,
          reminderTime: reminderDateTime,
          clearDueDate: _dueDate == null,
          clearReminderTime: reminderDateTime == null,
          photoPath: _photoPath,
          photosPaths: _photosPaths.isNotEmpty ? _photosPaths : null,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          locationHistory: _locationHistory.isNotEmpty
              ? _locationHistory
              : null,
        );
        await DatabaseService.instance.update(updatedTask);

        await NotificationService().cancelTaskReminder(widget.task!.id);
        if (reminderDateTime != null &&
            reminderDateTime.isAfter(DateTime.now()) &&
            !_completed) {
          await NotificationService().scheduleTaskReminder(updatedTask);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada com sucesso'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Estudar Flutter',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor, digite um título';
                        }
                        if (value.trim().length < 3) {
                          return 'Título deve ter pelo menos 3 caracteres';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Adicione mais detalhes...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 5,
                      maxLength: 500,
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue:
                          _categories.any((cat) => cat.id == _categoryId)
                          ? _categoryId
                          : 'default',
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              Text(category.icon),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _categoryId = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Baixa'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Média'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Alta'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Row(
                            children: [
                              Icon(Icons.priority_high, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Urgente'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Data de Vencimento'),
                        subtitle: Text(
                          _dueDate != null
                              ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                              : 'Nenhuma data selecionada',
                        ),
                        trailing: _dueDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _dueDate = null;
                                    _reminderTime = null;
                                  });
                                },
                              )
                            : null,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );
                          if (date != null) {
                            setState(() => _dueDate = date);
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_dueDate != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Hora do Lembrete'),
                          subtitle: Text(
                            _reminderTime != null
                                ? _reminderTime!.format(context)
                                : 'Nenhum lembrete configurado',
                          ),
                          trailing: _reminderTime != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _reminderTime = null);
                                  },
                                )
                              : null,
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _reminderTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() => _reminderTime = time);
                            }
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    Card(
                      child: SwitchListTile(
                        title: const Text('Tarefa Completa'),
                        subtitle: Text(
                          _completed
                              ? 'Esta tarefa está marcada como concluída'
                              : 'Esta tarefa ainda não foi concluída',
                        ),
                        value: _completed,
                        onChanged: (value) {
                          setState(() => _completed = value);
                        },
                        secondary: Icon(
                          _completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _completed ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Icon(Icons.photo_camera, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Fotos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_photosPaths.isNotEmpty)
                          Text(
                            '${_photosPaths.length} foto(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _takePicture,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Câmera'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeria'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickMultipleFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Múltiplas'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_photosPaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photosPaths.length,
                          itemBuilder: (context, index) {
                            final photoPath = _photosPaths[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () => _viewPhoto(photoPath),
                                    child: Container(
                                      width: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(
                                          File(photoPath),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.red,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        onPressed: () =>
                                            _removePhoto(photoPath),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Localização',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_latitude != null)
                          TextButton.icon(
                            onPressed: _removeLocation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_latitude != null && _longitude != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                          ),
                          title: Text(_locationName ?? 'Localização salva'),
                          subtitle: Text(
                            LocationService.instance.formatCoordinates(
                              _latitude!,
                              _longitude!,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _showLocationPicker,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _showLocationPicker,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Adicionar Localização'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _saveTask,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isEditing ? 'Atualizar Tarefa' : 'Criar Tarefa',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
