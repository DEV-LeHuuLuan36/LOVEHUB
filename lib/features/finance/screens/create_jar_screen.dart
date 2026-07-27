import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_text.dart';
import '../presentation/providers/finance_providers.dart';
import '../../couple/presentation/providers/couple_providers.dart';

// ─── VIETQR BANK DATA ────────────────────────────────────────────────────────
// VietQR short-codes for major Vietnamese banks.
// Sources: VietQR alliance, NAPAS VietQR specification.
class VietqrBank {
  const VietqrBank({
    required this.code,
    required this.name,
    required this.shortName,
    required this.logo,
  });
  final String code;      // VietQR short-code (e.g. "VCB", "MB")
  final String name;      // Full bank name
  final String shortName; // Short display name (e.g. "Vietcombank")
  final String logo;      // Emoji/logo character
}

const _vietqrBanks = <VietqrBank>[
  VietqrBank(code: 'VCB', name: 'Ngân hàng TMCP Ngoại Thương Việt Nam', shortName: 'Vietcombank', logo: '🏦'),
  VietqrBank(code: 'VNBK', name: 'Ngân hàng TMCP Ngoại Thương Việt Nam', shortName: 'Vietcombank', logo: '🏦'),
  VietqrBank(code: 'BIDV', name: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', shortName: 'BIDV', logo: '🏛️'),
  VietqrBank(code: 'TCB', name: 'Ngân hàng TMCP Kỹ thương Việt Nam', shortName: 'Techcombank', logo: '💹'),
  VietqrBank(code: 'CTG', name: 'Ngân hàng TMCP Công Thương Việt Nam', shortName: 'VietinBank', logo: '🏪'),
  VietqrBank(code: 'VietinBank', name: 'Ngân hàng TMCP Công Thương Việt Nam', shortName: 'VietinBank', logo: '🏪'),
  VietqrBank(code: 'MB', name: 'Ngân hàng TMCP Quân đội', shortName: 'MB Bank', logo: '🪖'),
  VietqrBank(code: 'VPB', name: 'Ngân hàng TMCP Việt Nam Thịnh Vượng', shortName: 'VPBank', logo: '🌿'),
  VietqrBank(code: 'TPB', name: 'Ngân hàng TMCP Tiên Phong', shortName: 'TPBank', logo: '🚀'),
  VietqrBank(code: 'ACB', name: 'Ngân hàng TMCP Á Châu', shortName: 'ACB', logo: '🅰️'),
  VietqrBank(code: 'SHB', name: 'Ngân hàng TMCP Sài Gòn - Hà Nội', shortName: 'SHB', logo: '🌏'),
  VietqrBank(code: 'MSB', name: 'Ngân hàng TMCP Hàng Hải', shortName: 'MSB', logo: '⚓'),
  VietqrBank(code: 'OCB', name: 'Ngân hàng TMCP Phương Đông', shortName: 'OCB', logo: '🅾️'),
  VietqrBank(code: 'HDB', name: 'Ngân hàng TMCP Phát triển Thành phố Hồ Chí Minh', shortName: 'HDBank', logo: '🏙️'),
  VietqrBank(code: 'VIB', name: 'Ngân hàng TMCP Quốc tế Việt Nam', shortName: 'VIB', logo: '🌐'),
  VietqrBank(code: 'NCB', name: 'Ngân hàng TMCP Quốc Dân', shortName: 'NCB', logo: '🏯'),
  VietqrBank(code: 'SCB', name: 'Ngân hàng TMCP Sài Gòn Thương Tín', shortName: 'SCB', logo: '🦁'),
  VietqrBank(code: 'PGB', name: 'Ngân hàng TMCP Petrolimex', shortName: 'PGBank', logo: '⛽'),
  VietqrBank(code: 'ABB', name: 'Ngân hàng TMCP An Bình', shortName: 'ABB', logo: '🌳'),
  VietqrBank(code: 'BAC', name: 'Ngân hàng TMCP Bắc Á', shortName: 'BacABank', logo: '❄️'),
  VietqrBank(code: 'EIB', name: 'Ngân hàng TMCP Xuất Nhập Khẩu Việt Nam', shortName: 'Eximbank', logo: '✈️'),
  VietqrBank(code: 'STB', name: 'Ngân hàng TMCP Sài Gòn Thương Tín', shortName: 'Sacombank', logo: '🦋'),
  VietqrBank(code: 'SACB', name: 'Ngân hàng TMCP Sài Gòn Công Thương', shortName: 'Saigonthuongtin', logo: '🏭'),
  VietqrBank(code: 'SHBVN', name: 'Ngân hàng TMCP Sài Gòn - Hà Nội', shortName: 'SHB', logo: '🌏'),
];

// ─── SCREEN ─────────────────────────────────────────────────────────────────
class CreateJarScreen extends ConsumerStatefulWidget {
  const CreateJarScreen({super.key});

  @override
  ConsumerState<CreateJarScreen> createState() => _CreateJarScreenState();
}

class _CreateJarScreenState extends ConsumerState<CreateJarScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _depositController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  String _selectedEmoji = '🐷';
  DateTime? _targetDate;
  VietqrBank? _selectedBank;
  bool _showBankSection = false;

  static const _emojiOptions = ['🐷', '🌸', '🏖️', '🎁', '💍', '🏠', '✈️', '🎂', '💎', '🎓', '🚗', '🏕️'];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _depositController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.gradientEnd,
              onPrimary: Colors.white,
              surface: AppColors.backgroundCard,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickBank() async {
    final picked = await showModalBottomSheet<VietqrBank>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BankPickerSheet(
        banks: _vietqrBanks,
        onSelect: (bank) => Navigator.of(ctx).pop(bank),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedBank = picked;
        _showBankSection = true;
      });
    }
  }

  void _toggleBankSection() {
    setState(() => _showBankSection = !_showBankSection);
    if (!_showBankSection) {
      // Clear bank data when collapsing
      _selectedBank = null;
      _accountNumberController.clear();
      _accountNameController.clear();
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amountDigits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final targetAmount = amountDigits.isEmpty ? 0 : (int.tryParse(amountDigits) ?? 0);
    final depositDigits = _depositController.text.replaceAll(RegExp(r'\D'), '');
    final initialDeposit = depositDigits.isEmpty ? 0 : (int.tryParse(depositDigits) ?? 0);

    if (name.isEmpty) {
      _showSnack('finance.errors.nameRequired'.tr());
      return;
    }
    if (targetAmount <= 0) {
      _showSnack('finance.errors.goalRequired'.tr());
      return;
    }
    if (initialDeposit < 0 || initialDeposit > targetAmount) {
      _showSnack('finance.errors.initialDepositRange'.tr());
      return;
    }

    // Validate bank fields if section is open and a bank is selected
    String? bankCode;
    String? bankAccountNumber;
    String? bankAccountName;
    if (_showBankSection && _selectedBank != null) {
      bankCode = _selectedBank!.code;
      bankAccountNumber = _accountNumberController.text.trim();
      bankAccountName = _accountNameController.text.trim();
      if (bankAccountNumber.isEmpty) {
        _showSnack('finance.errors.accountNumberRequired'.tr());
        return;
      }
      if (bankAccountName.isEmpty) {
        _showSnack('finance.errors.accountNameRequired'.tr());
        return;
      }
    }

    final coupleId = ref.read(currentCoupleIdProvider);
    if (coupleId == null) {
      _showSnack('finance.errors.notInCouple'.tr());
      return;
    }

    final result = await ref.read(createJarControllerProvider.notifier).createJar(
          coupleId: coupleId,
          name: name,
          emoji: _selectedEmoji,
          targetAmount: targetAmount,
          deadline: _targetDate,
          initialDeposit: initialDeposit,
          bankCode: bankCode,
          bankAccountNumber: bankAccountNumber,
          bankAccountName: bankAccountName,
        );

    if (!mounted) return;

    if (result == null) {
      _showSnack('finance.errors.saveFailed'.tr());
      return;
    }

    result.fold(
      (failure) => _showSnack(failure.message),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text('🐷 ', style: const TextStyle(fontSize: 16)),
                Text('finance.jarCreated'.tr()),
              ],
            ),
            backgroundColor: AppColors.gradientEnd,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        );
        Navigator.of(context).pop();
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.gradientEnd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountDigits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final previewAmount = amountDigits.isEmpty ? 0 : (int.tryParse(amountDigits) ?? 0);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildForm(previewAmount),
                    const SizedBox(height: AppSpacing.md),
                    _buildBankSection(),
                    const SizedBox(height: AppSpacing.md),
                    _buildPreview(previewAmount),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            _buildBottomSave(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Center(
            child: GradientText(
              'finance.createTitle'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        GestureDetector(
          onTap: _save,
          child: Text(
            'common.save'.tr(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gradientEnd),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(int previewAmount) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jar name
          Text(
            'finance.jarNameLabel'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          _DarkTextField(
            controller: _nameController,
            hint: 'e.g. Da Lat Trip',
            maxLength: 40,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),

          // Emoji picker
          Text(
            'finance.chooseIcon'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojiOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final emoji = _emojiOptions[i];
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected ? null : AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(AppSpacing.md),
                      border: isSelected ? null : Border.all(color: AppColors.borderSubtle),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.gradientEnd.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Target amount
          Text(
            'finance.goalAmount'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          _VNDTextField(
            controller: _amountController,
            hint: '5,000,000',
            onChanged: (v) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),

          // Target date
          Text(
            'finance.targetDateLabel'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundPrimary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _targetDate != null
                          ? _formatDate(_targetDate!)
                          : 'finance.selectDateHint'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        color: _targetDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Initial deposit
          Text(
            'finance.startWithAmount'.tr(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          _VNDTextField(
            controller: _depositController,
            hint: '0',
            onChanged: (v) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'finance.startWithAmountHint'.tr(),
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section toggle
        GestureDetector(
          onTap: _toggleBankSection,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                Text(
                  '🏦',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary.withValues(alpha: _showBankSection ? 1 : 0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'finance.fundBankAccount'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _showBankSection
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                if (!_showBankSection && _selectedBank != null)
                  _BankChip(bank: _selectedBank!),
                Icon(
                  _showBankSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Bank form fields (animated expand/collapse)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _showBankSection ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'finance.fundBankAccountDesc'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Bank picker
                Text(
                  'finance.bank'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: _pickBank,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _selectedBank != null ? AppColors.gradientEnd : AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_selectedBank != null) ...[
                          Text(_selectedBank!.logo, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedBank!.shortName} (${_selectedBank!.code})',
                              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Text(
                              'finance.selectBankHint'.tr(),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                        const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),

                if (_selectedBank != null) ...[
                  const SizedBox(height: AppSpacing.md),

                  // Account number
                  Text(
                    'finance.accountNumber'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _DarkTextField(
                    controller: _accountNumberController,
                    hint: 'e.g. 1234567890',
                    maxLength: 20,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Account holder name
                  Text(
                    'finance.accountHolder'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _DarkTextField(
                    controller: _accountNameController,
                    hint: 'e.g. NGUYEN VAN A',
                    maxLength: 50,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'finance.accountHolderHint'.tr(),
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(int previewAmount) {
    final jarName = _nameController.text.isEmpty
        ? 'finance.previewName'.tr()
        : _nameController.text;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'finance.preview'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.pinkGlow(intensity: 10),
                ),
                child: Center(
                  child: Text(_selectedEmoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jarName,
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (previewAmount > 0)
                      Text(
                        'finance.goalLabel'.tr(args: [formatVND(previewAmount)]),
                        style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      )
                    else
                      Text(
                        'finance.goalLabel'.tr(args: ['—']),
                        style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: 0,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSave() {
    final isLoading = ref.watch(createJarControllerProvider).isLoading;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.3)),
        ),
      ),
      child: GestureDetector(
        onTap: isLoading ? null : _save,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientEnd.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'finance.createJar'.tr(),
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── BANK PICKER SHEET ──────────────────────────────────────────────────────
class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({required this.banks, required this.onSelect});
  final List<VietqrBank> banks;
  final ValueChanged<VietqrBank> onSelect;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  List<VietqrBank> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.banks;
      } else {
        _filtered = widget.banks.where((b) =>
            b.code.toLowerCase().contains(q) ||
            b.name.toLowerCase().contains(q) ||
            b.shortName.toLowerCase().contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('🏦 ', style: TextStyle(fontSize: 18)),
                      Text(
                        'finance.selectBank'.tr(),
                        style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'finance.searchBank'.tr(),
                        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final bank = _filtered[i];
                  return ListTile(
                    leading: Text(bank.logo, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      bank.shortName,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      bank.name,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        bank.code,
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    onTap: () => widget.onSelect(bank),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── BANK CHIP ──────────────────────────────────────────────────────────────
class _BankChip extends StatelessWidget {
  const _BankChip({required this.bank});
  final VietqrBank bank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gradientEnd.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.gradientEnd, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(bank.logo, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            bank.shortName,
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gradientEnd,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FORM WIDGETS ───────────────────────────────────────────────────────────
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          counterText: '',
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _VNDTextField extends StatelessWidget {
  const _VNDTextField({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: onChanged,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'VND',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
