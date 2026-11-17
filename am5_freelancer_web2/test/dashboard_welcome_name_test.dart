import 'package:am5_freelancer_web/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('welcome name is formatted from the API profile values', () {
    expect(
      formatDashboardWelcomeName({'full_name': 'gANGA bHAVANI'}),
      'Ganga Bhavani',
    );
    expect(
      formatDashboardWelcomeName({
        'first_name': 'GANGA',
        'last_name': 'BHAVANI',
      }),
      'Ganga Bhavani',
    );
    expect(formatDashboardWelcomeName({'full_name': '  '}), 'Freelancer');
  });
}
