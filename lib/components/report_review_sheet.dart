import 'package:app_hiker/src/services/api_client.dart';
import 'package:app_hiker/src/services/review_service.dart';
import 'package:app_hiker/src/utils/pallete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

// Report of another user's review: a reason from the list and optional details.
class ReportReviewSheet extends StatefulWidget {
  final int reviewId;

  const ReportReviewSheet({super.key, required this.reviewId});

  // Returns true when the report was sent.
  static Future<bool> show(BuildContext context, int reviewId) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pallete.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ReportReviewSheet(reviewId: reviewId),
    );
    return sent ?? false;
  }

  @override
  State<ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends State<ReportReviewSheet> {
  static const _motivos = [
    'Spam ou propaganda',
    'Conteúdo ofensivo ou discurso de ódio',
    'Informação falsa ou enganosa',
    'Não tem relação com o local',
    'Outro',
  ];
  static const _outro = 'Outro';
  static const _maxDetalhes = 300;

  final _reviewService = ReviewService();
  final _detalhesController = TextEditingController();

  String? _motivo;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _detalhesController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final detalhes = _detalhesController.text.trim();
    if (_motivo == null) {
      setState(() => _errorMessage = 'Escolha o motivo da denúncia.');
      return;
    }
    if (_motivo == _outro && detalhes.isEmpty) {
      setState(() => _errorMessage = 'Conte o que há de errado com esta avaliação.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await _reviewService.reportReview(
        widget.reviewId,
        categoria: _motivo!,
        descricao: detalhes.isEmpty ? null : detalhes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SessionExpiredException {
      if (mounted) context.navigate('/login');
    } on ReviewException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Erro ao conectar com o servidor.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the text field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Denunciar avaliação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'A moderação vai analisar esta avaliação.',
                style: TextStyle(fontSize: 13, color: Pallete.whiteColor.withAlpha(160)),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _motivo,
                onChanged: (value) {
                  if (!_isSending) setState(() => _motivo = value);
                },
                child: Column(
                  children: [
                    for (final motivo in _motivos)
                      RadioListTile<String>(
                        value: motivo,
                        title: Text(motivo),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Pallete.primaryColor,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detalhesController,
                enabled: !_isSending,
                maxLength: _maxDetalhes,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: _motivo == _outro ? 'Conte o que há de errado' : 'Detalhes (opcional)',
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Pallete.borderColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Pallete.primaryColor, width: 1.5),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Pallete.errorColor)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Pallete.errorColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Pallete.whiteColor),
                        )
                      : const Text('Denunciar', style: TextStyle(color: Pallete.whiteColor, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
