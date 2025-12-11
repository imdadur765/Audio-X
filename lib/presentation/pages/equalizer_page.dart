import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/audio_effects_controller.dart';
import '../../data/models/audio_effects_model.dart';

class EqualizerPage extends StatelessWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer & Effects'),
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AudioEffectsController>().resetAll();
            },
            tooltip: 'Reset All',
          ),
        ],
      ),
      body: Consumer<AudioEffectsController>(
        builder: (context, controller, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preset Selector
                _buildPresetSelector(context, controller),
                const SizedBox(height: 32),

                // 5-Band Equalizer
                _buildEqualizer(context, controller),
                const SizedBox(height: 32),

                // Effects
                _buildEffects(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetSelector(BuildContext context, AudioEffectsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Presets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AudioEffects.builtInPresets.keys.map((preset) {
                final isSelected = controller.effects.currentPreset == preset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      controller.applyPreset(preset);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizer(BuildContext context, AudioEffectsController controller) {
    final frequencyLabels =
        controller.effects.frequencyLabels ?? List.filled(controller.effects.equalizerBands.length, '? Hz');
    final bandCount = controller.effects.equalizerBands.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Equalizer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bandCount, (index) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${controller.bandLevelToDb(controller.effects.equalizerBands[index]).toStringAsFixed(1)}dB',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: controller.effects.equalizerBands[index].toDouble(),
                          min: -1500,
                          max: 1500,
                          divisions: 30,
                          onChanged: (value) {
                            controller.setEqualizerBand(index, value.round());
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        index < frequencyLabels.length ? frequencyLabels[index] : '?',
                        style: const TextStyle(fontSize: 11)
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffects(BuildContext context, AudioEffectsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Audio Effects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Bass Boost
            ListTile(
              title: Text('Bass Boost: ${(controller.effects.bassBoost / 10).toStringAsFixed(0)}%'),
              subtitle: Slider(
                value: controller.effects.bassBoost.toDouble(),
                min: 0,
                max: 1000,
                divisions: 100,
                onChanged: (value) {
                  controller.setBassBoost(value.round());
                },
              ),
            ),

            // Virtualizer
            ListTile(
              title: Text('Virtualizer: ${(controller.effects.virtualizer / 10).toStringAsFixed(0)}%'),
              subtitle: Slider(
                value: controller.effects.virtualizer.toDouble(),
                min: 0,
                max: 1000,
                divisions: 100,
                onChanged: (value) {
                  controller.setVirtualizer(value.round());
                },
              ),
            ),

            // Reverb
            ListTile(
              title: const Text('Reverb'),
              subtitle: DropdownButton<int>(
                value: controller.effects.reverbPreset,
                isExpanded: true,
                items: List.generate(AudioEffects.reverbPresets.length, (index) {
                  return DropdownMenuItem(value: index, child: Text(AudioEffects.reverbPresets[index]));
                }),
                onChanged: (value) {
                  if (value != null) {
                    controller.setReverb(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
