import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_controller.dart';
import '../controllers/audio_effects_controller.dart';
import '../../data/models/audio_effects_model.dart';
import '../widgets/glass_background.dart';

class EqualizerPage extends StatelessWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AudioController, AudioEffectsController>(
      builder: (context, audioController, effectsController, child) {
        final accentColor = audioController.accentColor;
        final artworkPath = audioController.currentSong?.localArtworkPath;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Equalizer', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: Image.asset(
                'assets/images/back.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh, color: accentColor),
                  onPressed: () => effectsController.resetAll(),
                  tooltip: 'Reset All',
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Glass Background
              GlassBackground(
                artworkPath: artworkPath,
                accentColor: accentColor,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),

              // Content
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preset Selector
                      _buildPresetSelector(context, effectsController, accentColor),
                      const SizedBox(height: 24),

                      // 5-Band Equalizer
                      _buildEqualizer(context, effectsController, accentColor),
                      const SizedBox(height: 24),

                      // Effects
                      _buildEffects(context, effectsController, accentColor),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child, required BuildContext context}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPresetSelector(BuildContext context, AudioEffectsController controller, Color accentColor) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Presets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioEffects.builtInPresets.keys.map((preset) {
              final isSelected = controller.effects.currentPreset == preset;
              return GestureDetector(
                onTap: () => controller.applyPreset(preset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    preset,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizer(BuildContext context, AudioEffectsController controller, Color accentColor) {
    final frequencyLabels =
        controller.effects.frequencyLabels ?? List.filled(controller.effects.equalizerBands.length, '? Hz');
    final bandCount = controller.effects.equalizerBands.length;

    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.equalizer, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Equalizer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(bandCount, (index) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${controller.bandLevelToDb(controller.effects.equalizerBands[index]).toStringAsFixed(0)}dB',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accentColor,
                              inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                              thumbColor: accentColor,
                              overlayColor: accentColor.withValues(alpha: 0.2),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: controller.effects.equalizerBands[index].toDouble(),
                              min: -1500,
                              max: 1500,
                              onChanged: (value) => controller.setEqualizerBand(index, value.round()),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        index < frequencyLabels.length ? frequencyLabels[index] : '?',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffects(BuildContext context, AudioEffectsController controller, Color accentColor) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.graphic_eq, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Audio Effects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bass Boost
          _buildEffectSlider(
            context: context,
            title: 'Bass Boost',
            value: controller.effects.bassBoost.toDouble(),
            max: 1000,
            accentColor: accentColor,
            icon: Icons.speaker,
            onChanged: (value) => controller.setBassBoost(value.round()),
          ),
          const SizedBox(height: 20),

          // Virtualizer
          _buildEffectSlider(
            context: context,
            title: 'Virtualizer',
            value: controller.effects.virtualizer.toDouble(),
            max: 1000,
            accentColor: accentColor,
            icon: Icons.surround_sound,
            onChanged: (value) => controller.setVirtualizer(value.round()),
          ),
          const SizedBox(height: 20),

          // Reverb
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.waves, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Reverb',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  value: controller.effects.reverbPreset,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
                  items: List.generate(AudioEffects.reverbPresets.length, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(
                        AudioEffects.reverbPresets[index],
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) controller.setReverb(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffectSlider({
    required BuildContext context,
    required String title,
    required double value,
    required double max,
    required Color accentColor,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    final percentage = ((value / max) * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accentColor,
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            thumbColor: accentColor,
            overlayColor: accentColor.withValues(alpha: 0.2),
            trackHeight: 6,
          ),
          child: Slider(value: value, min: 0, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
