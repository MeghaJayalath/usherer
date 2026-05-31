import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/tourist.dart';

class TouristTile extends StatefulWidget {
  final Tourist tourist;
  final String groupId;
  final Function(String field, bool value) onStatusChanged;
  final Function(String note) onNoteChanged;
  final String? vehicleLabel;
  final bool isHighlighted;

  const TouristTile({
    super.key,
    required this.tourist,
    required this.groupId,
    required this.onStatusChanged,
    required this.onNoteChanged,
    this.vehicleLabel,
    this.isHighlighted = false,
  });

  @override
  State<TouristTile> createState() => _TouristTileState();
}

class _TouristTileState extends State<TouristTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  int _ripplePlayCount = 0;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_ripplePlayCount < 1) {
          _ripplePlayCount++;
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted && widget.isHighlighted) {
              _rippleController.forward(from: 0.0);
            }
          });
        }
      }
    });

    if (widget.isHighlighted) {
      _ripplePlayCount = 0;
      _rippleController.forward();
    }
  }

  @override
  void didUpdateWidget(TouristTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _ripplePlayCount = 0;
      _rippleController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(BuildContext context, String rawNumber) async {
    final String cleanNumber = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid contact number format'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final appUri = Uri.parse('whatsapp://send?phone=$cleanNumber');
    final webUri = Uri.parse('https://wa.me/$cleanNumber');

    try {
      final success = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open WhatsApp for "$cleanNumber"'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showEditNoteDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.tourist.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.tourist.name,
                          style: AppTypography.bodySecondary.copyWith(
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.bodyPrimary,
                decoration: InputDecoration(
                  hintText: 'Delays, extra bags, special requests...',
                  hintStyle: AppTypography.bodySecondary.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if ((widget.tourist.notes ?? '').isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          controller.clear();
                          widget.onNoteChanged('');
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onNoteChanged(controller.text.trim());
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Save Note',
                        style: AppTypography.bodyPrimary.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVip = widget.tourist.priority?.toUpperCase() == 'VIP';
    final hasNote =
        widget.tourist.notes != null && widget.tourist.notes!.isNotEmpty;

    final String rawContact = widget.tourist.contactInfo ?? '';
    final List<String> numbers = rawContact
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.replaceAll(RegExp(r'[^0-9+]'), '').isNotEmpty)
        .toList();

    final bool hasFirstNumber = numbers.isNotEmpty;
    final bool hasSecondNumber = numbers.length > 1;

    final Widget cardContent = GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showEditNoteDialog(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppColors.getTouristTileBgColor(
            pickUp: widget.tourist.pickUp,
            dropOff: widget.tourist.dropOff,
            isVip: isVip,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.getTouristTileBorderColor(
              pickUp: widget.tourist.pickUp,
              dropOff: widget.tourist.dropOff,
              isVip: isVip,
            ),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 5,
                  color: AppColors.getTouristTileIndicatorColor(
                    pickUp: widget.tourist.pickUp,
                    dropOff: widget.tourist.dropOff,
                    isVip: isVip,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tourist.name,
                                style: AppTypography.bodyPrimary.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration:
                                      (widget.tourist.pickUp &&
                                          widget.tourist.dropOff)
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: AppColors.getTouristTileTextColor(
                                    pickUp: widget.tourist.pickUp,
                                    dropOff: widget.tourist.dropOff,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.vehicleLabel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentMuted,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  widget.vehicleLabel!.toUpperCase(),
                                  style: AppTypography.labelChip.copyWith(
                                    color: AppColors.accent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if ((widget.tourist.hub != null &&
                                widget.tourist.hub!.isNotEmpty) ||
                            (widget.tourist.hotel != null &&
                                widget.tourist.hotel!.isNotEmpty)) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (widget.tourist.hub != null &&
                                  widget.tourist.hub!.isNotEmpty) ...[
                                Icon(
                                  Icons.hub_outlined,
                                  size: 11,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.tourist.hub!,
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              if (widget.tourist.hotel != null &&
                                  widget.tourist.hotel!.isNotEmpty) ...[
                                Icon(
                                  Icons.hotel_outlined,
                                  size: 11,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    widget.tourist.hotel!,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (widget.tourist.contactInfo != null &&
                            widget.tourist.contactInfo!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: widget.tourist.contactInfo!,
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Copied "${widget.tourist.contactInfo}" to clipboard',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  width: 300,
                                  backgroundColor: AppColors.accent,
                                ),
                              );
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 11,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.tourist.contactInfo!,
                                  style: AppTypography.bodySecondary.copyWith(
                                    fontSize: 11,
                                    color: AppColors.accent.withValues(
                                      alpha: 0.9,
                                    ),
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.accent
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (hasNote) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _showEditNoteDialog(context),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 11,
                                  color: AppColors.accent.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.tourist.notes!,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontSize: 11,
                                      color: AppColors.accent.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isVip)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0, left: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.vipGoldMuted,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.vipGold.withValues(
                              alpha: 0.3,
                            ),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'VIP',
                          style: AppTypography.labelChip.copyWith(
                            color: AppColors.vipGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0, left: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          context: context,
                          isActive: widget.tourist.pickUp,
                          activeColor: AppColors.early,
                          icon: Icons.flight_land_rounded,
                          label: 'PICKUP',
                          onTap: () {
                            widget.onStatusChanged(
                              'pickup',
                              !widget.tourist.pickUp,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          context: context,
                          isActive: widget.tourist.dropOff,
                          activeColor: AppColors.arrived,
                          icon: Icons.directions_car_rounded,
                          label: 'DROPOFF',
                          onTap: () {
                            widget.onStatusChanged(
                              'dropoff',
                              !widget.tourist.dropOff,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget mainTile = hasFirstNumber
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (hasSecondNumber)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                numbers[0],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox.shrink(),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasSecondNumber ? numbers[1] : numbers[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Colors.white,
                              size: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Dismissible(
                  key: ValueKey('dismiss_contact_${widget.tourist.id}'),
                  direction: hasSecondNumber
                      ? DismissDirection.horizontal
                      : DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.endToStart) {
                      HapticFeedback.mediumImpact();
                      await _launchWhatsApp(
                        context,
                        hasSecondNumber ? numbers[1] : numbers[0],
                      );
                    } else if (direction == DismissDirection.startToEnd &&
                        hasSecondNumber) {
                      HapticFeedback.mediumImpact();
                      await _launchWhatsApp(context, numbers[0]);
                    }
                    return false;
                  },
                  background: const SizedBox.shrink(),
                  secondaryBackground: const SizedBox.shrink(),
                  child: cardContent,
                ),
              ],
            ),
          )
        : cardContent;

    final Widget tileWithRipple = AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        if (_rippleController.value == 0.0 || _rippleController.value == 1.0) {
          return child!;
        }

        final val = _rippleController.value;
        final double scale1 = 1.0 + (Curves.easeOutCubic.transform(val) * 0.12);
        final double opacity1 =
            (1.0 - Curves.easeOutCubic.transform(val)) * 0.7;

        final double scale2 = 1.0 + (Curves.easeOutCubic.transform(val) * 0.06);
        final double opacity2 =
            (1.0 - Curves.easeOutCubic.transform(val)) * 0.4;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.scale(
                scale: scale2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: opacity2),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: opacity2 * 0.3,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.scale(
                scale: scale1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: opacity1),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: opacity1 * 0.5,
                        ),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: mainTile,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: tileWithRipple,
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required bool isActive,
    required Color activeColor,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.4)
                : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? activeColor
                  : AppColors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isActive
                    ? activeColor
                    : AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
