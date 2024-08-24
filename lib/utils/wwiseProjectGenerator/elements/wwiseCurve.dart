
import '../../../fileTypeUtils/audio/bnkIO.dart';
import '../../utils.dart';
import '../wwiseElement.dart';
import '../wwiseProperty.dart';

class WwiseCurve extends WwiseElement {
  final int? scalingType;
  final double scalingFactor;
  final bool applyCustomScaling;
  final List<BnkRtpcGraphPoint> points;

  WwiseCurve({
    required super.wuId,
    required super.project,
    required super.name,
    required bool isVolume,
    required this.scalingType,
    String fallbackFlag = _curveFallbackFlag,
    this.scalingFactor = 1,
    required this.points,
  }) :
    applyCustomScaling = isVolume && scalingType == _dbScalingType,
    super(
      tagName: "Curve",
      properties: [
        WwiseProperty("Flags", "int32", value: isVolume
          ? (scalingType != _noneScalingType ? "3" : "1")
          : fallbackFlag),
      ]
    ) {
      additionalChildren.add(makeXmlElement(name: "PointList", children: points.map((point) {
        return makeXmlElement(name: "Point", children: [
          makeXmlElement(name: "XPos", text: point.x.toString()),
          makeXmlElement(name: "YPos", text: _scaleY(point.y).toString()),
          if (point == points.first)
            makeXmlElement(name: "Flags", text: "5")
          else if (point == points.last)
            makeXmlElement(name: "Flags", text: "37")
          else
            makeXmlElement(name: "Flags", text: "0"),
          if (point.interpolation != 4)
            makeXmlElement(name: "SegmentShape", text: _bnkFadeInterpolationToWwiseShape[point.interpolation]!.name),
        ]);
      }).toList()));
    }

  double _scaleY(double y) {
    return (applyCustomScaling ? interpolateDb(y) : y) * scalingFactor;
  }

  static double interpolateDb(double y) {
    if (y <= _dbLookupTable.first.bnk)
      return _dbLookupTable.first.wwise;
    if (y >= _dbLookupTable.last.bnk)
      return _dbLookupTable.last.wwise;

    for (int i = 1; i < _dbLookupTable.length; i++) {
      if (y <= _dbLookupTable[i].bnk) {
        final x0 = _dbLookupTable[i - 1].bnk;
        final x1 = _dbLookupTable[i].bnk;
        final y0 = _dbLookupTable[i - 1].wwise;
        final y1 = _dbLookupTable[i].wwise;
        return y0 + (y1 - y0) * (y - x0) / (x1 - x0);
      }
    }

    return 0;
  }
}

const _bnkFadeInterpolationToWwiseShape = {
  0x0: (id: 0, name: "Log3"),	// Logarithmic (Base 3)
  0x1: (id: 1, name: "Log2"),	// Sine
  0x2: (id: 2, name: "Log1"),	// Logarithmic (Base 1.41)
  0x3: (id: 3, name: "InvertedSCurve"),	// Inverted S-Curve
  0x4: (id: 4, name: "Linear"),	// Linear
  0x5: (id: 6, name: "SCurve"),	// S-Curve
  0x6: (id: 7, name: "Exp1"),	// Exponential (Base 1.41)
  0x7: (id: 8, name: "Exp2"),	// Reciprocal Sine
  0x8: (id: 9, name: "Exp3"),	// Exponential (Base 3)
  0x9: (id: -1, name: "Constant"),	// Constant
};

const _curveFallbackFlag = "65537";

const _noneScalingType = 0;
const _dbScalingType = 2;

const List<({double bnk, double wwise})> _dbLookupTable = [
  (bnk: -1.0, wwise: -200.0),
  (bnk: -0.9999999404, wwise: -149.59999847400002),
  (bnk: -0.9999998808, wwise: -140.0),
  (bnk: -0.9999998212, wwise: -136.40000152599998),
  (bnk: -0.9999997616, wwise: -132.80000305160002),
  (bnk: -0.999999702, wwise: -130.40000152599998),
  (bnk: -0.9999996424, wwise: -129.19999694839998),
  (bnk: -0.9999995828, wwise: -128.0),
  (bnk: -0.9999995232, wwise: -126.8000030516),
  (bnk: -0.9999994636, wwise: -125.599998474),
  (bnk: -0.999999404, wwise: -124.400001526),
  (bnk: -0.9999992847, wwise: -123.1999969484),
  (bnk: -0.9999992251, wwise: -122.0),
  (bnk: -0.9999991059, wwise: -120.8000030516),
  (bnk: -0.9999989271, wwise: -119.599998474),
  (bnk: -0.9999988079, wwise: -118.400001526),
  (bnk: -0.9999986291, wwise: -117.1999969484),
  (bnk: -0.9999983907, wwise: -116.0),
  (bnk: -0.9999981523, wwise: -114.8000030516),
  (bnk: -0.9999979138, wwise: -113.599998474),
  (bnk: -0.9999976158, wwise: -112.400001526),
  (bnk: -0.9999972582, wwise: -111.1999969484),
  (bnk: -0.999996841, wwise: -110.0),
  (bnk: -0.9999963641, wwise: -108.8000030516),
  (bnk: -0.9999958277, wwise: -107.599998474),
  (bnk: -0.9999952316, wwise: -106.400001526),
  (bnk: -0.9999945164, wwise: -105.1999969484),
  (bnk: -0.9999936819, wwise: -104.0),
  (bnk: -0.9999927282, wwise: -102.8000030516),
  (bnk: -0.9999916553, wwise: -101.599998474),
  (bnk: -0.9999904633, wwise: -100.400001526),
  (bnk: -0.9999890327, wwise: -99.1999969484),
  (bnk: -0.9999874234, wwise: -98.0),
  (bnk: -0.9999855161, wwise: -96.8000030516),
  (bnk: -0.9999834299, wwise: -95.599998474),
  (bnk: -0.9999809265, wwise: -94.400001526),
  (bnk: -0.9999765754, wwise: -92.599998474),
  (bnk: -0.9999711514, wwise: -90.8000030516),
  (bnk: -0.9999645352, wwise: -89.0),
  (bnk: -0.9999563694, wwise: -87.1999969484),
  (bnk: -0.9999462962, wwise: -85.400001526),
  (bnk: -0.9999339581, wwise: -83.599998474),
  (bnk: -0.9999186993, wwise: -81.8000030516),
  (bnk: -0.9998999834, wwise: -80.0),
  (bnk: -0.999876976, wwise: -78.1999969484),
  (bnk: -0.9998486638, wwise: -76.400001526),
  (bnk: -0.9998137951, wwise: -74.599998474),
  (bnk: -0.9997709394, wwise: -72.8000030516),
  (bnk: -0.9997181892, wwise: -71.0),
  (bnk: -0.9996532798, wwise: -69.19999694840001),
  (bnk: -0.9995734096, wwise: -67.39999389639999),
  (bnk: -0.9994751811, wwise: -65.60000610360001),
  (bnk: -0.9993543625, wwise: -63.80000305159999),
  (bnk: -0.9992056489, wwise: -62.0),
  (bnk: -0.9990227818, wwise: -60.19999694840001),
  (bnk: -0.9987977147, wwise: -58.39999389639999),
  (bnk: -0.9985209107, wwise: -56.60000610360001),
  (bnk: -0.9981802702, wwise: -54.80000305159999),
  (bnk: -0.9977612495, wwise: -53.0),
  (bnk: -0.9972457886, wwise: -51.19999694840001),
  (bnk: -0.9966115355, wwise: -49.39999389639999),
  (bnk: -0.9958313107, wwise: -47.60000610360001),
  (bnk: -0.9948713779, wwise: -45.80000305159999),
  (bnk: -0.9936904311, wwise: -44.0),
  (bnk: -0.9922375083, wwise: -42.19999694840001),
  (bnk: -0.9904500842, wwise: -40.39999389639999),
  (bnk: -0.9882510304, wwise: -38.60000610360001),
  (bnk: -0.9855455756, wwise: -36.80000305159999),
  (bnk: -0.9822171926, wwise: -35.0),
  (bnk: -0.9781224132, wwise: -33.19999694840001),
  (bnk: -0.9730846286, wwise: -31.39999389639999),
  (bnk: -0.966886878, wwise: -29.60000610360001),
  (bnk: -0.9592619538, wwise: -27.800003051599987),
  (bnk: -0.9498812556, wwise: -26.0),
  (bnk: -0.9383404851, wwise: -24.199996948400013),
  (bnk: -0.9241422415, wwise: -22.39999389639999),
  (bnk: -0.9066745639, wwise: -20.60000610360001),
  (bnk: -0.8851846457, wwise: -18.800003051599987),
  (bnk: -0.8587462306, wwise: -17.0),
  (bnk: -0.8262199163, wwise: -15.199996948400013),
  (bnk: -0.7862038016, wwise: -13.399993896399991),
  (bnk: -0.7369732261, wwise: -11.600006103600009),
  (bnk: -0.6764063239, wwise: -9.800003051599987),
  (bnk: -0.6018928289, wwise: -8.0),
  (bnk: -6.1999998093, wwise: -6.199996948400013),
  (bnk: -4.4000000954, wwise: -4.399993896399991),
  (bnk: -2.5999999046, wwise: -2.600006103600009),
  (bnk: -0.8000000119, wwise: -0.8000030515999867),
  (bnk: 0.0000000000, wwise: 0.0000000000000000),
  (bnk: 0.2056717724, wwise: 2.0),
  (bnk: 0.3543457687, wwise: 3.8000030515999867),
  (bnk: 0.4751925468, wwise: 5.600006103600009),
  (bnk: 0.573420465, wwise: 7.399993896399991),
  (bnk: 0.6532631516, wwise: 9.199996948400013),
  (bnk: 0.7181617022, wwise: 11.0),
  (bnk: 0.7709132433, wwise: 12.800003051599987),
  (bnk: 0.813791275, wwise: 14.600006103600009),
  (bnk: 0.848643899, wwise: 16.39999389639999),
  (bnk: 0.8769731522, wwise: 18.199996948400013),
  (bnk: 0.8999999762, wwise: 20.0),
  (bnk: 0.9187169671, wwise: 21.800003051599987),
  (bnk: 0.9339306355, wwise: 23.60000610360001),
  (bnk: 0.9462968111, wwise: 25.39999389639999),
  (bnk: 0.9563484192, wwise: 27.199996948400013),
  (bnk: 0.9645186663, wwise: 29.0),
  (bnk: 0.9711596966, wwise: 30.800003051599987),
  (bnk: 0.9765577316, wwise: 32.60000610360001),
  (bnk: 0.9809454083, wwise: 34.39999389639999),
  (bnk: 0.9845118523, wwise: 36.19999694840001),
  (bnk: 0.9874107242, wwise: 38.0),
  (bnk: 0.9897670746, wwise: 39.80000305159999),
  (bnk: 0.9916823506, wwise: 41.60000610360001),
  (bnk: 0.9932391644, wwise: 43.39999389639999),
  (bnk: 0.994504571, wwise: 45.19999694840001),
  (bnk: 0.9955331683, wwise: 47.0),
  (bnk: 0.9963692427, wwise: 48.80000305159999),
  (bnk: 0.9970487952, wwise: 50.60000610360001),
  (bnk: 0.9976011515, wwise: 52.39999389639999),
  (bnk: 0.9980501533, wwise: 54.19999694840001),
  (bnk: 0.9984151125, wwise: 56.0),
  (bnk: 0.9987117648, wwise: 57.79998779279998),
  (bnk: 0.9989528656, wwise: 59.60000610359998),
  (bnk: 0.9991488457, wwise: 61.39999389640002),
  (bnk: 0.9993081689, wwise: 63.20001220720002),
  (bnk: 0.9994376302, wwise: 65.0),
  (bnk: 0.999542892, wwise: 66.79998779279998),
  (bnk: 0.9996284842, wwise: 68.60000610359998),
  (bnk: 0.9996979833, wwise: 70.39999389640002),
  (bnk: 0.9997545481, wwise: 72.20001220720002),
  (bnk: 0.9998005033, wwise: 74.0),
  (bnk: 0.9998378158, wwise: 75.79998779279998),
  (bnk: 0.9998681545, wwise: 77.60000610359998),
  (bnk: 0.9998928308, wwise: 79.39999389640002),
  (bnk: 0.9998952746, wwise: 79.60000610359998),
  (bnk: 0.9999088049, wwise: 80.79998779279998),
  (bnk: 0.999920547, wwise: 82.0),
  (bnk: 0.999930799, wwise: 83.20001220720002),
  (bnk: 0.9999397397, wwise: 84.39999389640002),
  (bnk: 0.9999475479, wwise: 85.60000610359998),
  (bnk: 0.9999542832, wwise: 86.79998779279998),
  (bnk: 0.9999601841, wwise: 88.0),
  (bnk: 0.9999653101, wwise: 89.20001220720002),
  (bnk: 0.9999697804, wwise: 90.39999389640002),
  (bnk: 0.9999737144, wwise: 91.60000610359998),
  (bnk: 0.9999771118, wwise: 92.79998779279998),
  (bnk: 0.9999800324, wwise: 94.0),
  (bnk: 0.9999825954, wwise: 95.20001220720002),
  (bnk: 0.9999848604, wwise: 96.39999389640002),
  (bnk: 0.9999868274, wwise: 97.60000610359998),
  (bnk: 0.9999884963, wwise: 98.79998779279998),
  (bnk: 0.9999899864, wwise: 100.0),
  (bnk: 0.9999912977, wwise: 101.20001220720002),
  (bnk: 0.9999924302, wwise: 102.39999389640002),
  (bnk: 0.9999933839, wwise: 103.60000610359998),
  (bnk: 0.9999942183, wwise: 104.79998779279998),
  (bnk: 0.9999949932, wwise: 106.0),
  (bnk: 0.9999956489, wwise: 107.20001220720002),
  (bnk: 0.9999961853, wwise: 108.39999389640002),
  (bnk: 0.9999966621, wwise: 109.60000610359998),
  (bnk: 0.999997139, wwise: 110.79998779279998),
  (bnk: 0.9999974966, wwise: 112.0),
  (bnk: 0.9999977946, wwise: 113.20001220720002),
  (bnk: 0.9999980927, wwise: 114.39999389640002),
  (bnk: 0.9999983311, wwise: 115.60000610359998),
  (bnk: 0.9999985695, wwise: 116.79998779279998),
  (bnk: 0.9999987483, wwise: 118.0),
  (bnk: 0.9999989271, wwise: 119.20001220720002),
  (bnk: 0.9999990463, wwise: 120.39999389640002),
  (bnk: 0.9999991655, wwise: 121.60000610359998),
  (bnk: 0.9999992847, wwise: 122.79998779279998),
  (bnk: 0.9999993443, wwise: 124.0),
  (bnk: 0.9999994636, wwise: 125.20001220720002),
  (bnk: 0.9999995232, wwise: 126.39999389640002),
  (bnk: 0.9999995828, wwise: 127.60000610359998),
  (bnk: 0.9999996424, wwise: 128.79998779279998),
  (bnk: 0.999999702, wwise: 131.20001220720002),
  (bnk: 0.9999997616, wwise: 133.60000610359998),
  (bnk: 0.9999998212, wwise: 136.0),
  (bnk: 0.9999998808, wwise: 140.0),
  (bnk: 0.9999999404, wwise: 150.0),
  (bnk: 1.0, wwise: 200.0),
];
