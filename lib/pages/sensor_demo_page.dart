
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorDemoPage extends StatelessWidget {
  const SensorDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accelerometer Demo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<AccelerometerEvent>(
        stream: accelerometerEventStream(
          samplingPeriod: SensorInterval.normalInterval,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Sensor tidak dapat diakses.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('Menunggu data accelerometer...'),
            );
          }

          // Deklarasikan event sebelum digunakan.
          final event = snapshot.data!;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.screen_rotation,
                      size: 60,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Data Accelerometer',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sensorValue('Sumbu X', event.x),
                    _sensorValue('Sumbu Y', event.y),
                    _sensorValue('Sumbu Z', event.z),
                    const SizedBox(height: 16),
                    const Text(
                      'Gerakkan atau miringkan perangkat '
                          'untuk melihat perubahan nilai sensor.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sensorValue(String label, double value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value.toStringAsFixed(2),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
