import 'package:flutter_test/flutter_test.dart';

import 'package:dgut_app/theme/dgut_motion.dart';

void main() {
  test('果冻是双轴四段挤压，不是单轴正弦', () {
    expect(DgutMotion.jellyX(0), 1.0);
    expect(DgutMotion.jellyY(0), 1.0);
    expect(DgutMotion.jellyX(0.28), closeTo(1.20, 1e-6));
    expect(DgutMotion.jellyY(0.28), closeTo(0.84, 1e-6));
    expect(DgutMotion.jellyX(1), 1.0);
    expect(DgutMotion.jellyY(1), 1.0);
  });

  test('边缘模糊线性回落到 9px，不归零', () {
    expect(DgutMotion.edgeSigma(1), closeTo(20, 1e-6));
    expect(DgutMotion.edgeSigma(0), closeTo(9, 1e-6));
  });

  test('顶栏模糊是平方曲线', () {
    expect(DgutMotion.barSigma(34), 0);
    expect(DgutMotion.barSigma(94), closeTo(30, 1e-6));
    expect(DgutMotion.barSigma(64), closeTo(7.5, 1e-6));
  });
}
