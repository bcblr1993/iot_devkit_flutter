import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../l10n/generated/app_localizations.dart';
import '../../models/certificate_config.dart';
import '../../services/certificate_address_parser.dart';
import '../../services/certificate_generator_service.dart';
import '../../services/certificate_package_builder.dart';
import '../lab/lab.dart';
import '../components/form_grid.dart';

class CertificateGeneratorTool extends StatefulWidget {
  const CertificateGeneratorTool({super.key});

  @override
  State<CertificateGeneratorTool> createState() =>
      _CertificateGeneratorToolState();
}

class _CertificateGeneratorToolState extends State<CertificateGeneratorTool> {
  final _passwordController = TextEditingController();
  final _addressesController = TextEditingController(
    text: 'localhost\n127.0.0.1\n::1',
  );
  final _hostsIpController = TextEditingController(text: '127.0.0.1');
  final _service = const CertificateGeneratorService();

  CertificateUsage _usage = CertificateUsage.shared;
  CertificateOutputFormat _format = CertificateOutputFormat.pem;
  bool _showPassword = false;
  bool _isGenerating = false;
  CertificateGenerationResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refreshPreview);
    _addressesController.addListener(_refreshPreview);
    _hostsIpController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _addressesController.dispose();
    _hostsIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final parsed = _parsedAddresses;
    final request = _request;
    final plan = CertificatePackageBuilder.buildPlan(
      request: request,
      addresses: parsed,
      now: DateTime.now(),
      redactSecrets: true,
    );
    final validationError = _validationError(parsed);

    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, l10n),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LabSection(
                    title: l10n.certUsage,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FormGrid(
                          minItemWidth: 320,
                          children: [
                            _buildUsageSelector(context, l10n),
                            _buildFormatSelector(context, l10n),
                            _buildPasswordField(context, l10n),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHint(context, l10n.certOpenSslHint),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LabSection(
                    title: l10n.certSanAddresses,
                    trailing: Text(
                      l10n.certLocalDefaults,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FormGrid(
                          minItemWidth: 360,
                          children: [
                            LabField(
                              label: l10n.certSanAddresses,
                              controller: _addressesController,
                              minLines: 5,
                              maxLines: 8,
                              hintText: l10n.certSanHint,
                              errorText: parsed.hasInvalid
                                  ? '${l10n.certInvalidAddresses}: ${parsed.invalidTokens.join(', ')}'
                                  : null,
                            ),
                            LabField(
                              label: l10n.certHostsIp,
                              controller: _hostsIpController,
                              hintText: l10n.certHostsIpHint,
                              errorText: _hostsIpError(l10n),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildParsedAddressChips(context, l10n, parsed),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LabSection(
                    title: l10n.certOutputPreview,
                    child: _buildOutputPreview(context, l10n, plan),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: LabButton(
                        label: l10n.certGenerateZip,
                        icon: Icons.archive_outlined,
                        variant: LabButtonVariant.primary,
                        size: LabButtonSize.lg,
                        fullWidth: true,
                        loading: _isGenerating,
                        onPressed: validationError == null && !_isGenerating
                            ? _generateZip
                            : null,
                      ),
                    ),
                    if (_lastResult != null) ...[
                      const SizedBox(width: 12),
                      LabButton(
                        label: l10n.certCopyConfig,
                        icon: Icons.copy_all_outlined,
                        size: LabButtonSize.lg,
                        onPressed: _copyGeneratedConfig,
                      ),
                      const SizedBox(width: 12),
                      LabButton(
                        label: l10n.certOpenFolder,
                        icon: Icons.folder_open_outlined,
                        size: LabButtonSize.lg,
                        onPressed: _openGeneratedFolder,
                      ),
                    ],
                  ],
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    validationError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_lastResult != null) ...[
                  const SizedBox(height: 12),
                  _buildGeneratedPath(context, l10n, _lastResult!.zipPath),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.workspace_premium_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.certGenerator,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.certGeneratorDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageSelector(BuildContext context, AppLocalizations l10n) {
    return LabSegmented<CertificateUsage>(
      fullWidth: true,
      value: _usage,
      segments: [
        LabSegment(CertificateUsage.https, l10n.certUsageHttps),
        LabSegment(CertificateUsage.mqtts, l10n.certUsageMqtts),
        LabSegment(CertificateUsage.shared, l10n.certUsageShared),
      ],
      onChanged: (v) {
        setState(() {
          _usage = v;
          _lastResult = null;
        });
      },
    );
  }

  Widget _buildFormatSelector(BuildContext context, AppLocalizations l10n) {
    return LabSegmented<CertificateOutputFormat>(
      fullWidth: true,
      value: _format,
      segments: const [
        LabSegment(CertificateOutputFormat.pem, 'PEM'),
        LabSegment(CertificateOutputFormat.pkcs12, 'PKCS12'),
      ],
      onChanged: (v) {
        setState(() {
          _format = v;
          _lastResult = null;
        });
      },
    );
  }

  Widget _buildPasswordField(BuildContext context, AppLocalizations l10n) {
    final needsPassword = _format == CertificateOutputFormat.pkcs12;
    return LabField(
      label: l10n.certPassword,
      controller: _passwordController,
      enabled: needsPassword,
      obscure: !_showPassword,
      hintText:
          needsPassword ? l10n.certPasswordHint : l10n.certPemNoPasswordHint,
      errorText: needsPassword && _passwordController.text.trim().isEmpty
          ? l10n.certPasswordRequired
          : null,
      suffixWidget: needsPassword
          ? IconButton(
              tooltip: _showPassword ? l10n.hidePassword : l10n.showPassword,
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
            )
          : const Icon(Icons.lock_open_outlined),
    );
  }

  Widget _buildHint(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParsedAddressChips(
    BuildContext context,
    AppLocalizations l10n,
    ParsedCertificateAddresses parsed,
  ) {
    final theme = Theme.of(context);
    if (!parsed.hasValid) {
      return Text(
        l10n.certAddressRequired,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.certParsedAddresses,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final address in parsed.addresses)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  address.isIp ? Icons.tag_outlined : Icons.public_outlined,
                  size: 16,
                ),
                label: Text(address.label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutputPreview(
    BuildContext context,
    AppLocalizations l10n,
    CertificatePackagePlan plan,
  ) {
    final theme = Theme.of(context);

    return FormGrid(
      minItemWidth: 360,
      children: [
        _PreviewPanel(
          title: l10n.certFiles,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final file in plan.fileNames)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(file)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _PreviewPanel(
          title: l10n.certEnv,
          child: SelectableText(
            plan.envText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ),
        _PreviewPanel(
          title: l10n.certHostsExample,
          child: SelectableText(
            plan.hostsText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedPath(
    BuildContext context,
    AppLocalizations l10n,
    String path,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '${l10n.certZipSavedTo}: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: SelectableText(
              path,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  ParsedCertificateAddresses get _parsedAddresses {
    return CertificateAddressParser.parse(
      _addressesController.text,
      includeLocalDefaults: true,
    );
  }

  CertificateGenerationRequest get _request {
    return CertificateGenerationRequest(
      usage: _usage,
      format: _format,
      password: _passwordController.text,
      addressText: _addressesController.text,
      hostsBindingIp: _hostsIpController.text,
    );
  }

  String? _validationError(ParsedCertificateAddresses parsed) {
    final l10n = AppLocalizations.of(context)!;
    if (_format == CertificateOutputFormat.pkcs12 &&
        _passwordController.text.trim().isEmpty) {
      return l10n.certPasswordRequired;
    }
    if (!parsed.hasValid) {
      return l10n.certAddressRequired;
    }
    if (parsed.hasInvalid) {
      return '${l10n.certInvalidAddresses}: ${parsed.invalidTokens.join(', ')}';
    }
    final hostsError = _hostsIpError(l10n);
    if (hostsError != null) return hostsError;
    return null;
  }

  String? _hostsIpError(AppLocalizations l10n) {
    final value = _hostsIpController.text.trim();
    if (value.isEmpty) return null;
    if (!CertificateAddressParser.isValidIp(value)) {
      return l10n.certHostsIpInvalid;
    }
    return null;
  }

  Future<void> _generateZip() async {
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parsedAddresses;
    final validationError = _validationError(parsed);
    if (validationError != null) {
      showLabToast(context, title: validationError, kind: LabStatus.error);
      return;
    }

    final request = _request;
    final previewPlan = CertificatePackageBuilder.buildPlan(
      request: request,
      addresses: parsed,
      now: DateTime.now(),
      redactSecrets: true,
    );
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.certGenerateZip,
      fileName: previewPlan.zipFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null) {
      if (mounted) {
        showLabToast(context,
            title: l10n.certGenerationCancelled, kind: LabStatus.info);
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _lastResult = null;
    });

    try {
      final result = await _service.generateZip(
        request: request,
        outputPath: outputPath,
      );
      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
      showLabToast(context, title: l10n.certGenerated, kind: LabStatus.ok);
    } catch (e) {
      if (!mounted) return;
      showLabToast(context,
          title: '${l10n.certGenerationFailed}: $e', kind: LabStatus.error);
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _copyGeneratedConfig() async {
    final result = _lastResult;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.plan.envText));
    if (mounted) {
      showLabToast(context,
          title: AppLocalizations.of(context)!.copySuccess, kind: LabStatus.ok);
    }
  }

  Future<void> _openGeneratedFolder() async {
    final result = _lastResult;
    if (result == null) return;
    final folder = p.dirname(result.zipPath);
    if (Platform.isMacOS) {
      await Process.run('open', [folder]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [folder], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folder]);
    }
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {
        _lastResult = null;
      });
    }
  }
}

class _PreviewPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _PreviewPanel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
