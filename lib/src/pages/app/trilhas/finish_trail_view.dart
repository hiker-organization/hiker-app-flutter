import 'dart:io';

import 'package:app_hiker/components/place_picker.dart';
import 'package:app_hiker/components/profile_summary_header.dart';
import 'package:app_hiker/components/trail_map.dart';
import 'package:app_hiker/src/models/user_profile.dart';
import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/places_service.dart';
import 'package:app_hiker/src/services/trail_tracker.dart';
import 'package:app_hiker/src/services/trilha_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:app_hiker/src/utils/trail_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';

// RF26: summary of the finished trail and the fields of RN26.1 (nota*, descrição*,
// imagens, labels) before saving it.
class FinishTrailView extends StatefulWidget {
  final UserProfile? profile;
  final int? postsCount;
  // Called after the trail is saved or discarded.
  final VoidCallback onClosed;

  const FinishTrailView({super.key, required this.profile, this.postsCount, required this.onClosed});

  @override
  State<FinishTrailView> createState() => _FinishTrailViewState();
}

class _FinishTrailViewState extends State<FinishTrailView> {
  static const _maxDescricao = 150;
  static const _maxNome = 100;
  static const _maxFotos = 5;
  static const _maxFotoBytes = 10 * 1024 * 1024;

  final _tracker = TrailTracker.instance;
  final _trilhaService = TrilhaService();
  final _imagePicker = ImagePicker();

  final _descricaoController = TextEditingController();
  final _tagController = TextEditingController();

  late String _nome = _defaultName();
  PlaceSuggestion? _local;
  int _nota = 0;
  final List<String> _tags = [];
  final List<XFile> _fotos = [];
  bool _compartilhada = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descricaoController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _defaultName() {
    final cidade = _tracker.cidade;
    if (cidade != null && cidade.isNotEmpty) return 'Trilha em $cidade';
    return 'Trilha de ${formatTrailDate(_tracker.startedAt ?? DateTime.now())}';
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _nome);
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Nome da trilha'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: _maxNome,
          decoration: const InputDecoration(hintText: 'Ex.: Cachoeira da Pavuna'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Pallete.whiteColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salvar', style: TextStyle(color: Pallete.primaryColor)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nome != null && nome.isNotEmpty) setState(() => _nome = nome);
  }

  void _addTags(String raw) {
    final novas = raw.split(',').map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty && !_tags.contains(t));
    setState(() {
      _tags.addAll(novas);
      _tagController.clear();
    });
  }

  Future<void> _pickFotos() async {
    final restantes = _maxFotos - _fotos.length;
    if (restantes <= 0) return;

    final escolhidas = await _imagePicker.pickMultiImage(limit: restantes, imageQuality: 85, maxWidth: 1920);
    final validas = <XFile>[];
    final problemas = <String>[];
    for (final foto in escolhidas.take(restantes)) {
      final extensao = foto.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extensao)) {
        problemas.add('${foto.name}: formato não suportado');
      } else if (await foto.length() > _maxFotoBytes) {
        problemas.add('${foto.name}: maior que 10 MB');
      } else {
        validas.add(foto);
      }
    }
    setState(() {
      _fotos.addAll(validas);
      _errorMessage = problemas.isEmpty ? null : problemas.join('\n');
    });
  }

  String? _validate() {
    if (_local == null) return 'Escolha o local da trilha.';
    if (_nota < 1) return 'Dê uma nota de 1 a 5 estrelas para a trilha.';
    final descricao = _descricaoController.text.trim();
    if (descricao.isEmpty) return 'Descreva sua experiência na trilha.';
    if (descricao.length > _maxDescricao) return 'A descrição pode ter no máximo $_maxDescricao caracteres.';
    return null;
  }

  Future<void> _save() async {
    if (_tagController.text.trim().isNotEmpty) _addTags(_tagController.text);

    final error = _validate();
    setState(() => _errorMessage = error);
    if (error != null) return;

    setState(() => _isSaving = true);
    try {
      await _trilhaService.create(
        nome: _nome,
        localId: _local!.placeId,
        cidade: _tracker.cidade,
        estado: _tracker.estado,
        distanciaM: _tracker.distanceM,
        passos: _tracker.steps,
        duracao: _tracker.elapsed,
        nota: _nota,
        descricao: _descricaoController.text.trim(),
        rota: _tracker.route,
        compartilhada: _compartilhada,
        iniciadaEm: _tracker.startedAt ?? DateTime.now(),
        tags: _tags,
        fotoPaths: _fotos.map((f) => f.path).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trilha salva!')));
      await _tracker.discard();
      widget.onClosed();
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } on TrilhaException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Erro ao conectar com o servidor.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Descartar trilha?'),
        content: const Text('O trajeto, os passos e a distância registrados serão perdidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar', style: TextStyle(color: Pallete.whiteColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar', style: TextStyle(color: Pallete.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _tracker.discard();
    widget.onClosed();
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Pallete.surfaceColor,
      contentPadding: const EdgeInsets.all(12),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Pallete.primaryColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSummaryHeader(profile: widget.profile, postsCount: widget.postsCount),
          Divider(height: 1, color: Pallete.whiteColor.withAlpha(20)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildTitle(),
                const SizedBox(height: 12),
                PlacePicker(
                  selected: _local,
                  enabled: !_isSaving,
                  decoration: _decoration('Onde foi? Busque o parque, trilha ou pico'),
                  onChanged: (place) => setState(() => _local = place),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descricaoController,
                  enabled: !_isSaving,
                  maxLength: _maxDescricao,
                  minLines: 2,
                  maxLines: 3,
                  decoration: _decoration('Descreva sua experiência'),
                ),
                const SizedBox(height: 4),
                TrailMap(route: _tracker.route, height: 220),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${formatKm(_tracker.distanceM)} km',
                      style: const TextStyle(color: Pallete.whiteColor, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatDuration(_tracker.elapsed),
                      style: TextStyle(color: Pallete.whiteColor.withAlpha(180)),
                    ),
                    Text(
                      '${_tracker.steps} passos',
                      style: const TextStyle(color: Pallete.whiteColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tagController,
                  enabled: !_isSaving,
                  onChanged: (value) {
                    if (value.contains(',')) _addTags(value);
                  },
                  onSubmitted: _addTags,
                  decoration: _decoration(
                    'Palavras que definem o local',
                    suffix: IconButton(icon: const Icon(Icons.add), onPressed: () => _addTags(_tagController.text)),
                  ),
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Pallete.primaryColor.withAlpha(99),
                              onDeleted: () => setState(() => _tags.remove(tag)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                _buildFotos(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _compartilhada,
                  activeTrackColor: Pallete.primaryColor,
                  onChanged: _isSaving ? null : (value) => setState(() => _compartilhada = value),
                  title: const Text('Compartilhar no feed', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Outros trilheiros poderão ver o trajeto e a sua avaliação.',
                    style: TextStyle(fontSize: 13, color: Pallete.whiteColor.withAlpha(160)),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Pallete.errorColor)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Pallete.accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Pallete.whiteColor),
                          )
                        : const Text('Salvar', style: TextStyle(color: Pallete.whiteColor, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Pallete.surfaceColor,
                      side: BorderSide(color: Pallete.whiteColor.withAlpha(60)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancelar', style: TextStyle(color: Pallete.whiteColor, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _isSaving ? null : _editName,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(_nome, style: const TextStyle(color: Pallete.whiteColor, fontSize: 18)),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit, size: 16, color: Pallete.whiteColor.withAlpha(160)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _tracker.estado ?? '',
                style: const TextStyle(color: Pallete.whiteColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatTrailDate(_tracker.startedAt ?? DateTime.now()),
              style: const TextStyle(color: Pallete.whiteColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: _isSaving ? null : () => setState(() => _nota = i),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        i <= _nota ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Pallete.primaryColor,
                        size: 26,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFotos() {
    const size = 72.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Pallete.surfaceColor,
          borderRadius: BorderRadius.circular(6),
          child: ListTile(
            dense: true,
            onTap: _isSaving || _fotos.length >= _maxFotos ? null : _pickFotos,
            title: Text(
              'Adicione imagens (${_fotos.length}/$_maxFotos)',
              style: TextStyle(color: Pallete.whiteColor.withAlpha(200)),
            ),
            trailing: const Icon(Icons.add, color: Pallete.whiteColor),
          ),
        ),
        if (_fotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final foto in _fotos)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(foto.path), width: size, height: size, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: _isSaving ? null : () => setState(() => _fotos.remove(foto)),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 13, color: Pallete.whiteColor),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
