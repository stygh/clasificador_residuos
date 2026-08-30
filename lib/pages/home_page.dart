import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/prediction_response.dart';
import '../services/api_service.dart';
import '../utils/image_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();

  File? _selectedImage;
  PredictionResponse? _prediction;
  bool _processingImage = false;
  bool _classifying = false;

  bool get _busy => _processingImage || _classifying;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
  }

  Future<void> _recoverLostImage() async {
    final LostDataResponse lostData = await _picker.retrieveLostData();
    if (lostData.isEmpty || lostData.files == null || lostData.files!.isEmpty) {
      return;
    }
    await _prepareImage(File(lostData.files!.first.path));
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_busy) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 2048,
        maxHeight: 2048,
        requestFullMetadata: false,
      );
      if (picked == null) return;
      await _prepareImage(File(picked.path));
    } catch (_) {
      _showMessage('No fue posible abrir la cámara o la galería.');
    }
  }

  Future<void> _prepareImage(File source) async {
    setState(() {
      _processingImage = true;
      _prediction = null;
    });

    try {
      final File optimized = await ImageUtils.optimize(source);
      if (!mounted) return;
      setState(() {
        _selectedImage = optimized;
      });
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No fue posible preparar la fotografía seleccionada.');
    } finally {
      if (mounted) {
        setState(() {
          _processingImage = false;
        });
      }
    }
  }

  Future<void> _classify() async {
    final File? image = _selectedImage;
    if (image == null || _busy) {
      _showMessage('Primero debes seleccionar o tomar una fotografía.');
      return;
    }

    setState(() {
      _classifying = true;
      _prediction = null;
    });

    try {
      final PredictionResponse result = await _apiService.predict(image);
      if (!mounted) return;
      setState(() {
        _prediction = result;
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Ocurrió un error inesperado durante la clasificación.');
    } finally {
      if (mounted) {
        setState(() {
          _classifying = false;
        });
      }
    }
  }

  void _reset() {
    if (_busy) return;
    setState(() {
      _selectedImage = null;
      _prediction = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _apiService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clasificador de Residuos'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Captura o selecciona una fotografía y envíala al modelo alojado en Cloud Run.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              _ImagePreview(image: _selectedImage),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Cámara'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _selectedImage == null || _busy ? null : _classify,
                icon: const Icon(Icons.auto_awesome),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('Clasificar residuo'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _selectedImage == null || _busy ? null : _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Nueva clasificación'),
              ),
              if (_processingImage) ...<Widget>[
                const SizedBox(height: 24),
                const _ProgressMessage(message: 'Optimizando la fotografía…'),
              ],
              if (_classifying) ...<Widget>[
                const SizedBox(height: 24),
                const _ProgressMessage(
                  message: 'Enviando la fotografía a Cloud Run…',
                ),
              ],
              if (_prediction != null) ...<Widget>[
                const SizedBox(height: 24),
                _ResultCard(prediction: _prediction!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.image});

  final File? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: image == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.image_outlined, size: 72),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Todavía no se ha seleccionado una fotografía.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : Image.file(image!, fit: BoxFit.cover),
    );
  }
}

class _ProgressMessage extends StatelessWidget {
  const _ProgressMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.prediction});

  final PredictionResponse prediction;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> probabilities =
        prediction.probabilities.entries.toList()
          ..sort(
            (MapEntry<String, double> a, MapEntry<String, double> b) =>
                b.value.compareTo(a.value),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Resultado de la clasificación',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              prediction.classSpanish.isEmpty
                  ? prediction.className
                  : prediction.classSpanish,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (prediction.className.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Clase técnica: ${prediction.className}',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Confianza: ${prediction.confidencePercentage.toStringAsFixed(2)} %',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (probabilities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Probabilidades por categoría',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...probabilities.map((MapEntry<String, double> entry) {
                final double percentage =
                    entry.value <= 1 ? entry.value * 100 : entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(entry.key)),
                      Text(
                        '${percentage.toStringAsFixed(2)} %',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
